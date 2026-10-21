import Foundation
import XCTest
@testable import LedgerForge

@MainActor
final class PlanningWritePersistenceTests: XCTestCase {
    private func plan(month: String = "2026-10") throws -> FundingPlanDTO {
        let zero = try Money(canonicalDecimal: "0.00", currency: "QAR")
        let value = try FundingPlan(id: "persisted-plan", workspaceID: "default-workspace",
            month: SelectedStatementMonth(canonical: month),
            expectedFixedEarnings: Money(canonicalDecimal: "100.00", currency: "QAR"),
            expectedFixedProvenance: .manual, expectedVariableEarnings: zero,
            expectedVariableProvenance: .manual, expectedDeductions: zero,
            expectedDeductionsProvenance: .manual, balances: [], qatarCommitments: [],
            indiaCommitments: [], configuredTransferFee: zero,
            configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 3, observationDate: StatementDate(canonical: "2026-10-18")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual,
            updatedAtISO: "2026-10-21T00:00:00Z", calculationVersion: .budgetV1,
            keepInCBQ: zero, referenceMode: .manual)
        return try value.persistenceDTO()
    }

    private func changed(_ original: FundingPlanDTO) throws -> FundingPlanDTO {
        var value = try original.allocationCalculationInput()
        value.expectedFixedEarnings = try Money(canonicalDecimal: "200.00", currency: "QAR")
        value.updatedAtISO = "2026-10-21T00:00:01Z"
        return try value.persistenceDTO()
    }

    private func request(for snapshot: PlanningWriteSnapshot, plan: FundingPlanDTO) throws -> PlanningChangeCommitRequest {
        .init(requestID: UUID().uuidString.lowercased(), requestDigest: String(repeating: "b", count: 64),
              workspaceID: plan.workspaceId, month: plan.planMonthISO, planID: plan.id,
              expectedWriteRevision: try XCTUnwrap(snapshot.writeRevision),
              committedAtISO: "2026-10-21T00:00:02Z")
    }

    private func editor(_ plan: FundingPlanDTO, fixedText: String) throws -> MonthlyPlanScratchpad {
        let model = try plan.allocationCalculationInput()
        return MonthlyPlanScratchpad(plan: model, canonical: model,
            rawText: ["fixed": fixedText], fieldErrors: [:], untouchedZeroFields: [],
            unavailableBalanceAccountIDs: [], preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
    }

    private func companionAnchor(_ scratchpad: MonthlyPlanScratchpad,
                                 scope: CompanionMerge.SyncScope,
                                 previous: CompanionMonthAnchor? = nil) throws -> CompanionMonthAnchor {
        let metadata = MonthlyPlanSyncAdapter.metadata(for: scratchpad,
            lexicalContext: .init(defaultLocaleIdentifier: "en_US_POSIX", localeIdentifiersByField: [:]),
            retaining: previous?.metadata ?? .init(), previousScratchpad: previous?.scratchpad)
        let draft = try CompanionMacMonthContext.make(scratchpad: scratchpad, metadata: metadata,
            accounts: [.init(repositoryAccountId: "planning-bank", workspaceId: scratchpad.plan.workspaceID,
                name: "Planning bank", type: .bank, nativeCurrency: CurrencyCode("QAR"), status: .active,
                preferredDisplayName: "Planning bank", selectionContext: "Local test")],
            manuallyExcludedPlanningAccountIDs: [], receiptTransactions: [], latestAlDarQuote: nil,
            selectedHistoryAccountIDs: [])
        return try .init(scratchpad: scratchpad, metadata: draft.binding(for: scope).baselineMetadata,
            bankCurrencies: draft.bankCurrencies, fundingAccountIDs: draft.fundingAccountIDs,
            excludedHistoryAccountIDs: draft.excludedHistoryAccountIDs, context: draft.context)
    }

    func testReceiptReplayIsHistoricalAndDoesNotPublishAgain() throws {
        let provider = DatabaseProvider(inMemory: true)
        let original = try plan()
        _ = try provider.fundingPlanRepo.savePlan(original)
        let current = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        let request = PlanningChangeCommitRequest(requestID: UUID().uuidString.lowercased(),
            requestDigest: String(repeating: "a", count: 64), workspaceID: original.workspaceId,
            month: original.planMonthISO, planID: original.id,
            expectedWriteRevision: try XCTUnwrap(current.writeRevision),
            committedAtISO: "2026-10-21T00:00:01Z")
        let first = try provider.fundingPlanRepo.commitPlanningChange(request) { snapshot in
            PlanningChangeCommitCandidate(plan: try XCTUnwrap(snapshot.plan),
                scratchpad: snapshot.scratchpad, resultJSON: "{}")
        }
        XCTAssertEqual(first.outcome, .noChange)
        XCTAssertEqual(first.committedRevision, current.monthRevision.counter)
        let newer = try provider.fundingPlanRepo.savePlan(original, expected: current.monthRevision, origin: .manual)
        let replay = try provider.fundingPlanRepo.commitPlanningChange(request) { _ in
            XCTFail("A replay must not rebuild or republish the old candidate")
            throw PlanningWriteError.invalidCandidate
        }
        XCTAssertEqual(replay, first)
        XCTAssertEqual(try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO).monthRevision, newer)
    }

    func testStaleNativeRawSaveCannotReplaceNewerCanonical() throws {
        let provider = DatabaseProvider(inMemory: true)
        let original = try plan()
        _ = try provider.fundingPlanRepo.savePlan(original)
        let baseline = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO).monthRevision
        _ = try provider.fundingPlanRepo.savePlan(original, expected: baseline, origin: .chatgpt)
        XCTAssertThrowsError(try provider.fundingPlanRepo.removeScratchpad(
            workspaceId: original.workspaceId, month: original.planMonthISO, expected: baseline)) { error in
            XCTAssertEqual(error as? PlanningWriteError, .staleRevision)
        }
    }

    func testInMemoryLateFailureRollsBackPlanRevisionAndReceipt() throws {
        let memory = InMemoryRepositoryProvider()
        let original = try plan()
        _ = try memory.fundingPlanRepo.savePlan(original)
        let baseline = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        let request = try request(for: baseline, plan: original)
        let updated = try changed(original)
        memory.injectPlanningFailureBeforeReceipt(true)
        XCTAssertThrowsError(try memory.fundingPlanRepo.commitPlanningChange(request) { _ in
            .init(plan: updated, scratchpad: nil, resultJSON: "{}")
        })
        memory.injectPlanningFailureBeforeReceipt(false)
        let after = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(after.plan, original)
        XCTAssertEqual(after.scratchpad, baseline.scratchpad)
        XCTAssertEqual(after.monthRevision, baseline.monthRevision)
        XCTAssertNil(try memory.fundingPlanRepo.planningRequestReceipt(requestID: request.requestID))
        let accepted = try memory.fundingPlanRepo.commitPlanningChange(request) { _ in
            .init(plan: updated, scratchpad: nil, resultJSON: "{}")
        }
        XCTAssertEqual(accepted.outcome, .saved)
        XCTAssertEqual(accepted.committedRevision, baseline.monthRevision.counter + 1)
    }

    func testSQLiteReceiptInsertFailureRollsBackCompleteChange() throws {
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let original = try plan()
        _ = try sqlite.fundingPlanRepo.savePlan(original)
        let baseline = try sqlite.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        let request = try request(for: baseline, plan: original)
        let updated = try changed(original)
        try sqlite.database.execute(sql: """
            CREATE TRIGGER planning_receipt_test_abort BEFORE INSERT ON planning_request_receipts
            BEGIN SELECT RAISE(ABORT, 'injected receipt failure'); END;
            """)
        XCTAssertThrowsError(try sqlite.fundingPlanRepo.commitPlanningChange(request) { _ in
            .init(plan: updated, scratchpad: nil, resultJSON: "{}")
        })
        try sqlite.database.execute(sql: "DROP TRIGGER planning_receipt_test_abort;")
        let after = try sqlite.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(after.plan, original)
        XCTAssertEqual(after.monthRevision, baseline.monthRevision)
        XCTAssertNil(try sqlite.fundingPlanRepo.planningRequestReceipt(requestID: request.requestID))
        let receipt = try sqlite.fundingPlanRepo.commitPlanningChange(request) { _ in
            .init(plan: updated, scratchpad: nil, resultJSON: "{}")
        }
        XCTAssertEqual(receipt.outcome, .saved)
    }

    func testPairedSQLiteMCPReceiptFailureRollsBackAllFiveSurfacesThenReplayIsReadOnly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "LedgerForge-PlanningPairedWrite-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sqlite = try SQLiteRepositoryProvider(path: directory.appendingPathComponent("ledger.sqlite").path)
        defer { sqlite.database.close() }
        let provider = DatabaseProvider.verifiedSQLite(sqlite)
        let original = try plan()
        let initialEditor = try editor(original, fixedText: "100.00")
        _ = try provider.workspaceRepo.upsertWorkspace(.init(id: original.workspaceId,
            name: "Planning write mechanics", createdAtISO: "2026-10-21T00:00:00Z"))
        _ = try provider.accountRepo.upsertAccount(.init(id: "planning-bank", workspaceId: original.workspaceId,
            name: "Planning bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        _ = try provider.fundingPlanRepo.savePlan(original, retaining: initialEditor.dto())
        let session = CompanionSyncSessionDTO(sessionID: UUID().uuidString, workspaceID: original.workspaceId,
            activationEpoch: try provider.fundingPlanRepo.companionActivationEpoch(),
            phoneID: UUID().uuidString, protocolVersion: 1, disposition: "active")
        try provider.fundingPlanRepo.createCompanionSession(session)
        let scope = session.scope(month: original.planMonthISO)
        let anchor = try companionAnchor(initialEditor, scope: scope)
        let binding = try anchor.binding(for: scope)
        let initialRevision = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO).monthRevision
        let initialized = try provider.fundingPlanRepo.commitCompanionMonth(.init(
            sessionID: session.sessionID, workspaceID: original.workspaceId, month: original.planMonthISO,
            expectedActivationEpoch: session.activationEpoch, expectedStateRevision: nil,
            expectedMonthRevision: initialRevision, expectedScratchpad: initialEditor.dto(),
            editor: initialEditor.dto(), canonical: nil, binding: binding, metadata: anchor.metadata,
            operation: .initialize(binding.baselineDocument), currentAnchor: anchor))
        XCTAssertEqual(initialized.disposition, .initialized)

        let before = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        let request = try request(for: before, plan: original)
        let updated = try changed(original)
        let updatedEditor = try editor(updated, fixedText: "200.00")
        let updatedAnchor = try companionAnchor(updatedEditor, scope: scope, previous: anchor)
        let updatedBinding = try updatedAnchor.binding(for: scope)
        func candidate(_ snapshot: PlanningWriteSnapshot) throws -> PlanningChangeCommitCandidate {
            let pairedRequest = CompanionMonthCommitRequest(sessionID: session.sessionID,
                workspaceID: original.workspaceId, month: original.planMonthISO,
                expectedActivationEpoch: session.activationEpoch,
                expectedStateRevision: try XCTUnwrap(snapshot.companionMonth).stateRevision,
                expectedMonthRevision: snapshot.monthRevision,
                expectedScratchpad: try XCTUnwrap(snapshot.scratchpad),
                editor: try updatedEditor.dto(), canonical: updated,
                binding: binding, metadata: updatedAnchor.metadata,
                operation: .localEdit(updatedBinding.baselineDocument), currentAnchor: updatedAnchor)
            return .init(plan: updated, scratchpad: try updatedEditor.dto(),
                resultJSON: "{\"outcome\":\"saved\"}", companionRequest: pairedRequest)
        }

        try sqlite.database.execute(sql: """
            CREATE TRIGGER planning_paired_receipt_abort BEFORE INSERT ON planning_request_receipts
            BEGIN SELECT RAISE(ABORT, 'injected paired receipt failure'); END;
            """)
        XCTAssertThrowsError(try provider.fundingPlanRepo.commitPlanningChange(request, build: candidate))
        try sqlite.database.execute(sql: "DROP TRIGGER planning_paired_receipt_abort;")
        let afterFailure = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(afterFailure.plan, before.plan)
        XCTAssertEqual(afterFailure.scratchpad, before.scratchpad)
        XCTAssertEqual(afterFailure.monthRevision, before.monthRevision)
        XCTAssertEqual(try provider.fundingPlanRepo.companionMonth(sessionID: session.sessionID,
            workspaceID: original.workspaceId, month: original.planMonthISO), initialized.stored)
        XCTAssertNil(try provider.fundingPlanRepo.planningRequestReceipt(requestID: request.requestID))

        let receipt = try provider.fundingPlanRepo.commitPlanningChange(request, build: candidate)
        XCTAssertEqual(receipt.outcome, .saved)
        let afterCommit = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(afterCommit.plan, updated)
        XCTAssertEqual(afterCommit.scratchpad, try updatedEditor.dto())
        XCTAssertEqual(afterCommit.monthRevision.counter, before.monthRevision.counter + 1)
        XCTAssertEqual(afterCommit.monthRevision.latestOrigin, .chatgpt)
        XCTAssertEqual(afterCommit.companionMonth?.stateRevision, initialized.stored.stateRevision + 1)
        XCTAssertEqual(try provider.fundingPlanRepo.planningRequestReceipt(requestID: request.requestID), receipt)

        let replay = try provider.fundingPlanRepo.commitPlanningChange(request) { _ in
            XCTFail("Historical receipt replay must not rebuild the paired request")
            throw PlanningWriteError.invalidCandidate
        }
        XCTAssertEqual(replay, receipt)
        let afterReplay = try provider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(afterReplay.monthRevision, afterCommit.monthRevision)
        XCTAssertEqual(afterReplay.companionMonth, afterCommit.companionMonth)
    }

    func testNewAccountMembershipInvalidatesWriteRevisionWithoutMonthSave() throws {
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let original = try plan()
        _ = try sqlite.fundingPlanRepo.savePlan(original)
        let first = try sqlite.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        _ = try sqlite.accountRepo.upsertAccount(.init(id: "new-planning-account", workspaceId: original.workspaceId,
            name: "New planning account", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        let changedContext = try sqlite.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertNotEqual(first.writeRevision, changedContext.writeRevision)
        XCTAssertEqual(first.monthRevision, changedContext.monthRevision)
        let staleRequest = try request(for: first, plan: original)
        XCTAssertThrowsError(try sqlite.fundingPlanRepo.commitPlanningChange(staleRequest) { _ in
            XCTFail("Stale dependency context must reject before building")
            return .init(plan: original, scratchpad: nil, resultJSON: "{}")
        }) { error in XCTAssertEqual(error as? PlanningWriteError, .staleRevision) }
    }

    func testReopenedProviderInvalidatesOldWriteRevisionEvenAtSameCounter() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LedgerForge-PlanningRevision-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("ledger.sqlite").path
        let original = try plan()
        let firstProvider = try SQLiteRepositoryProvider(path: path)
        _ = try firstProvider.fundingPlanRepo.savePlan(original)
        let first = try firstProvider.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        try firstProvider.database.checkpointAndClose()
        let reopened = try SQLiteRepositoryProvider(path: path, migrations: allMigrations, access: .existing)
        defer { reopened.database.close() }
        let second = try reopened.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(first.monthRevision.counter, second.monthRevision.counter)
        XCTAssertNotEqual(first.writeRevision, second.writeRevision)
        XCTAssertNotEqual(first.monthRevision.providerID, second.monthRevision.providerID)
    }

    func testNewReserveDesignationInvalidatesDependencyMembership() throws {
        let memory = InMemoryRepositoryProvider()
        let original = try plan()
        _ = try memory.fundingPlanRepo.savePlan(original)
        _ = try memory.accountRepo.upsertAccount(.init(id: "reserve-bank", workspaceId: original.workspaceId,
            name: "Reserve bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        let before = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        let designation = try ReserveDesignation(id: "new-reserve", workspaceID: original.workspaceId,
            accountID: "reserve-bank", title: "Selected reserve", kind: .accountCash,
            target: PlanningAmount(Money(canonicalDecimal: "100.00", currency: "QAR")))
        try memory.intelligenceRepo.applyPlanning(.reserve(designation, replacing: nil))
        let after = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertNotEqual(before.writeRevision, after.writeRevision)
        XCTAssertEqual(before.monthRevision, after.monthRevision)
    }

    func testNonemptyPreferenceSetsProduceStableRevisionAndMembershipChangeInvalidatesIt() throws {
        let memory = InMemoryRepositoryProvider()
        let original = try plan()
        _ = try memory.fundingPlanRepo.savePlan(original)
        _ = try memory.accountRepo.upsertAccount(.init(id: "excluded-bank", workspaceId: original.workspaceId,
            name: "Excluded bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        var preferences = IntelligencePreferences(workspaceID: original.workspaceId)
        preferences.salaryRuleIDs = ["salary-b", "salary-a"]
        preferences.excludedPlanningAccountIDs = ["excluded-bank"]
        try memory.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: nil))
        let first = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        for _ in 0..<10 {
            XCTAssertEqual(try memory.fundingPlanRepo.planningWriteSnapshot(
                workspaceID: original.workspaceId, month: original.planMonthISO).writeRevision, first.writeRevision)
        }
        let previous = preferences
        preferences.salaryRuleIDs.insert("salary-c")
        try memory.intelligenceRepo.applyPlanning(.preferences(preferences, replacing: previous))
        let second = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(second.monthRevision, first.monthRevision)
        XCTAssertNotEqual(second.writeRevision, first.writeRevision)
    }

    func testAccountLifecycleChangeInvalidatesContextWithoutMonthPublication() throws {
        let sqlite = try SQLiteRepositoryProvider(path: ":memory:")
        defer { sqlite.database.close() }
        let original = try plan()
        _ = try sqlite.workspaceRepo.upsertWorkspace(.init(id: original.workspaceId,
            name: "Planning write mechanics", createdAtISO: "2026-10-21T00:00:00Z"))
        _ = try sqlite.accountRepo.upsertAccount(.init(id: "lifecycle-bank", workspaceId: original.workspaceId,
            name: "Planning bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        _ = try sqlite.fundingPlanRepo.savePlan(original)
        let before = try sqlite.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertTrue(try sqlite.accountRepo.markAccountHistoryOnly(accountId: "lifecycle-bank",
            workspaceId: original.workspaceId, markedAtISO: "2026-10-21T00:00:01Z"))
        let after = try sqlite.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(after.monthRevision, before.monthRevision)
        XCTAssertNotEqual(after.writeRevision, before.writeRevision)
    }

    func testExistingReserveTargetChangeInvalidatesContextWithoutMonthPublication() throws {
        let memory = InMemoryRepositoryProvider()
        let original = try plan()
        _ = try memory.fundingPlanRepo.savePlan(original)
        _ = try memory.accountRepo.upsertAccount(.init(id: "reserve-target-bank", workspaceId: original.workspaceId,
            name: "Reserve bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        let designation = try ReserveDesignation(id: "reserve-target", workspaceID: original.workspaceId,
            accountID: "reserve-target-bank", title: "Selected reserve", kind: .accountCash,
            target: PlanningAmount(Money(canonicalDecimal: "100.00", currency: "QAR")))
        try memory.intelligenceRepo.applyPlanning(.reserve(designation, replacing: nil))
        let before = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        var revised = designation
        revised.target = try PlanningAmount(Money(canonicalDecimal: "200.00", currency: "QAR"))
        try memory.intelligenceRepo.applyPlanning(.reserve(revised, replacing: designation))
        let after = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(after.monthRevision, before.monthRevision)
        XCTAssertNotEqual(after.writeRevision, before.writeRevision)
    }

    func testRawABARestoresExactBytesButCannotRestoreAnOldWriteRevision() throws {
        let memory = InMemoryRepositoryProvider()
        let original = try plan()
        _ = try memory.fundingPlanRepo.savePlan(original)
        let initial = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        let rawA = try editor(original, fixedText: "100.00").dto()
        let firstRevision = try memory.fundingPlanRepo.saveScratchpad(rawA, expected: initial.monthRevision)
        let firstA = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        var changedEditor = try editor(original, fixedText: "100.00")
        changedEditor.rawText["fixed"] = "100."
        let rawB = try changedEditor.dto()
        let secondRevision = try memory.fundingPlanRepo.saveScratchpad(rawB, expected: firstRevision)
        let thirdRevision = try memory.fundingPlanRepo.saveScratchpad(rawA, expected: secondRevision)
        let restoredA = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(restoredA.plan, firstA.plan)
        XCTAssertEqual(restoredA.scratchpad, firstA.scratchpad)
        XCTAssertEqual(restoredA.monthRevision, thirdRevision)
        XCTAssertEqual(restoredA.monthRevision.counter, firstA.monthRevision.counter + 2)
        XCTAssertNotEqual(restoredA.writeRevision, firstA.writeRevision)
        let staleRequest = try request(for: firstA, plan: original)
        XCTAssertThrowsError(try memory.fundingPlanRepo.commitPlanningChange(staleRequest) { _ in
            XCTFail("An A→B→A raw cycle cannot revive an old write baseline")
            return .init(plan: original, scratchpad: rawA, resultJSON: "{}")
        }) { error in XCTAssertEqual(error as? PlanningWriteError, .staleRevision) }
    }

    func testNewQualifyingSalaryReceiptInvalidatesPreviouslyEmptyQueryMembership() throws {
        let memory = InMemoryRepositoryProvider()
        let original = try plan()
        let bankID = "salary-receipt-bank"
        _ = try memory.workspaceRepo.upsertWorkspace(.init(id: original.workspaceId,
            name: "Planning write mechanics", createdAtISO: "2026-10-21T00:00:00Z"))
        _ = try memory.accountRepo.upsertAccount(.init(id: bankID, workspaceId: original.workspaceId,
            name: "Salary bank", accountType: "bank", nativeCurrency: "QAR",
            createdAtISO: "2026-10-21T00:00:00Z"))
        let statementID = "salary-receipt-statement"
        let digest = String(repeating: "a", count: 64)
        let statement = SalaryStatementDTO(id: statementID, workspaceId: original.workspaceId,
            documentId: "salary-document", importSessionId: "salary-import",
            normalizedDocumentId: "salary-normalized-document", sourceFingerprintAlgorithm: "sha256",
            sourceFingerprintDigest: digest, sourceAuthorityCode: "local_original",
            parserProfileId: "test.salary", parserProfileVersion: "1", financialPeriodISO: original.planMonthISO,
            printDateISO: "2026-10-20", documentKindCode: "regular_salary", nativeCurrency: "QAR",
            printedEarningsMinor: 10_000, printedEarningsDecimal: "100.00",
            printedDeductionsMinor: nil, printedDeductionsDecimal: nil,
            printedNetMinor: 10_000, printedNetDecimal: "100.00",
            printedPaymentMinor: 10_000, printedPaymentDecimal: "100.00",
            createdAtISO: "2026-10-21T00:00:00Z", components: [])
        memory.injectPlanningReceiptDependencies(statement: statement)
        var linked = try original.allocationCalculationInput()
        linked.assistance = PlanAssistance(workspaceID: original.workspaceId, month: original.planMonthISO,
            payslipFunding: PayslipFunding(statementID: statementID, fingerprintAlgorithm: "sha256",
                fingerprintDigest: digest, accountID: bankID,
                net: try PlanningAmount(Money(canonicalDecimal: "100.00", currency: "QAR")),
                balanceAcknowledgement: nil))
        let linkedDTO = try linked.persistenceDTO()
        _ = try memory.fundingPlanRepo.savePlan(linkedDTO)
        let before = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertTrue(before.receiptTransactions.isEmpty)

        let incoming = TransactionDTO(id: "new-salary-receipt", workspaceId: original.workspaceId,
            accountId: bankID, postedDateISO: "2026-10-21", description: "Salary payment",
            nativeCurrency: "QAR", amountMinor: 10_000, amountDecimal: "100.00", direction: "credit",
            isTrusted: true, trustedAtISO: "2026-10-21T00:00:01Z",
            createdAtISO: "2026-10-21T00:00:01Z")
        memory.injectPlanningReceiptDependencies(trustedTransaction: incoming)
        let after = try memory.fundingPlanRepo.planningWriteSnapshot(
            workspaceID: original.workspaceId, month: original.planMonthISO)
        XCTAssertEqual(after.receiptTransactions.map(\.id), [incoming.id])
        XCTAssertEqual(after.monthRevision, before.monthRevision)
        XCTAssertNotEqual(after.writeRevision, before.writeRevision)
        let stale = try request(for: before, plan: linkedDTO)
        XCTAssertThrowsError(try memory.fundingPlanRepo.commitPlanningChange(stale) { _ in
            XCTFail("The transaction must be rejected before building against the old empty receipt set")
            return .init(plan: linkedDTO, scratchpad: nil, resultJSON: "{}")
        }) { error in XCTAssertEqual(error as? PlanningWriteError, .staleRevision) }
    }
}
