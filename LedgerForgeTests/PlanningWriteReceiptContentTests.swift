import Foundation
import XCTest
@testable import LedgerForge

@MainActor
final class PlanningWriteReceiptContentTests: XCTestCase {
    private let workspace = "receipt-test"
    private let month = "2026-11"
    private let transferID = "a966b69a-84b4-4523-aa95-14c8909ff67d"

    private func money(_ text: String, _ currency: String = "QAR") throws -> Money {
        try Money(canonicalDecimal: text, currency: currency)
    }

    private func plan() throws -> FundingPlan {
        let zero = try money("0.00")
        return try FundingPlan(
            id: "plan", workspaceID: workspace, month: SelectedStatementMonth(canonical: month),
            expectedFixedEarnings: money("1000.00"), expectedFixedProvenance: .carried(sourcePlanID: "prior"),
            expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
            expectedDeductions: zero, expectedDeductionsProvenance: .manual,
            balances: [.init(id: "balance", accountID: "bank", nativeCurrency: CurrencyCode("QAR"),
                             included: true, money: money("100.00"),
                             provenance: .capturedAccountBalance(capturedAtISO: "2026-10-31T12:00:00Z"),
                             financialBalanceDate: StatementDate(canonical: "2026-10-31"))],
            qatarCommitments: [.init(id: "bill", label: "Existing bill", money: money("20.00"), included: true,
                                     fundingAccountID: nil, provenance: .manual,
                                     dueDate: StatementDate(canonical: "2026-11-10"))],
            indiaCommitments: [], configuredTransferFee: zero, configuredTransferFeeProvenance: .manual,
            planningFX: FundingPlanFX(inrPerQAR: 20, observationDate: StatementDate(canonical: "2026-11-01")),
            plannedInvestment: zero, plannedInvestmentProvenance: .manual,
            updatedAtISO: "2026-11-01T00:00:00Z", calculationVersion: .budgetV1,
            keepInCBQ: money("10.00"), referenceMode: .manual,
            assistance: .init(workspaceID: workspace, month: month, carriedBillDates: ["bill": "2026-11-15"])
        )
    }

    private func request(_ changes: [[String: Any]]) throws -> PlanningChangeRequest {
        let data = try JSONSerialization.data(withJSONObject: [
            "request_id": "68cb8090-3f23-4bca-97d8-7c6b60023f63",
            "workspace_id": workspace, "month": month, "plan_id": "plan",
            "expected_write_revision": "planning-write-v1:" + String(repeating: "a", count: 64),
            "changes": changes
        ])
        return try PlanningChangeRequest.decode(data)
    }

    private func items(_ receipt: [String: Any], _ key: String) throws -> [[String: Any]] {
        try XCTUnwrap(receipt[key] as? [[String: Any]])
    }

    private func item(_ values: [[String: Any]], type: String, field: String) -> [String: Any]? {
        values.first { entry in
            let target = entry["target"] as? [String: Any]
            return target?["type"] as? String == type && target?["field"] as? String == field
        }
    }

    func testReportsExactMonthlyTargetAndChangedFieldBeforeAfterWithoutFullPlan() throws {
        let original = try plan()
        let command = try request([["type": "monthly_amount", "field": "keep_in_cbq",
                                    "amount": ["currency": "QAR", "decimal": "25.00"]]])
        var changed = original
        changed.keepInCBQ = try money("25.00")
        let receipt = try PlanningWriteReceiptContent.make(request: command, before: original, after: changed)
        let changes = try items(receipt, "changes")
        XCTAssertEqual(changes.count, 1)
        let target = try XCTUnwrap(changes[0]["target"] as? [String: String])
        XCTAssertEqual(target, ["type": "monthly_amount", "field": "keep_in_cbq"])
        let prior = try XCTUnwrap(changes[0]["before"] as? [String: String])
        let saved = try XCTUnwrap(changes[0]["after"] as? [String: String])
        XCTAssertEqual(prior, ["currency": "QAR", "decimal": "10.00"])
        XCTAssertEqual(saved["decimal"], "25.00")
        XCTAssertNil(receipt["plan"])
        XCTAssertTrue(try items(receipt, "derived_changes").isEmpty)

        let noOp = try PlanningWriteReceiptContent.make(request: command, before: changed, after: changed)
        XCTAssertTrue(try items(noOp, "changes").isEmpty)
        XCTAssertTrue(try items(noOp, "derived_changes").isEmpty)
    }

    func testSavedReceiptRemainsHistoricalAfterLaterCanonicalEdit() throws {
        let original = try plan()
        let command = try request([["type": "monthly_amount", "field": "keep_in_cbq",
                                    "amount": ["currency": "QAR", "decimal": "25.00"]]])
        var committed = original
        committed.keepInCBQ = try money("25.00")
        let receipt = try PlanningWriteReceiptContent.make(request: command, before: original, after: committed)
        let durable = try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys])
        var later = committed
        later.keepInCBQ = try money("30.00")
        XCTAssertEqual(later.keepInCBQ, try money("30.00"))
        let replayBasis = try XCTUnwrap(JSONSerialization.jsonObject(with: durable) as? [String: Any])
        let replayedChange = try XCTUnwrap(items(replayBasis, "changes").first)
        XCTAssertEqual((replayedChange["before"] as? [String: String])?["decimal"], "10.00")
        XCTAssertEqual((replayedChange["after"] as? [String: String])?["decimal"], "25.00")
        XCTAssertNil(replayBasis["plan"])
    }

    func testReportsBalanceProvenanceAndClearedBillOverrideAsDerivedEffects() throws {
        let original = try plan()
        let command = try request([
            ["type": "planning_balance", "balance_id": "balance", "account_id": "bank",
             "fields": ["amount": ["currency": "QAR", "decimal": "100.00"]]],
            ["type": "obligation", "region": "qatar", "obligation_id": "bill",
             "fields": ["due_date": "2026-11-18"]]
        ])
        var changed = original
        changed.balances[0].provenance = .manual
        changed.balances[0].financialBalanceDate = nil
        changed.qatarCommitments[0].dueDate = try StatementDate(canonical: "2026-11-18")
        changed.assistance?.carriedBillDates?["bill"] = nil
        let receipt = try PlanningWriteReceiptContent.make(request: command, before: original, after: changed)
        let changes = try items(receipt, "changes")
        XCTAssertEqual(changes.count, 1) // The entered balance amount was already equal.
        XCTAssertNotNil(item(changes, type: "obligation", field: "due_date"))
        let derived = try items(receipt, "derived_changes")
        XCTAssertEqual(item(derived, type: "planning_balance", field: "provenance")?["before"] as? String,
                       "captured_account_balance")
        XCTAssertEqual(item(derived, type: "planning_balance", field: "provenance")?["after"] as? String, "manual")
        XCTAssertEqual(item(derived, type: "planning_balance", field: "financial_balance_date")?["before"] as? String,
                       "2026-10-31")
        XCTAssertTrue(item(derived, type: "planning_balance", field: "financial_balance_date")?["after"] is NSNull)
        XCTAssertEqual(item(derived, type: "obligation", field: "carried_date_override")?["before"] as? String,
                       "2026-11-15")
        XCTAssertTrue(item(derived, type: "obligation", field: "carried_date_override")?["after"] is NSNull)
    }

    func testReportsCreatedTransferSavedFieldsAndDerivedPrincipal() throws {
        let original = try plan()
        let command = try request([["type": "transfer", "action": "create", "transfer_id": transferID,
                                    "fields": ["from_account_id": "bank", "to_account_id": "nre",
                                               "received": ["currency": "INR", "decimal": "2000.00"],
                                               "date": "2026-11-20", "funding_transfer_id": NSNull(),
                                               "required_india_funding": NSNull()]]])
        var changed = original
        changed.assistance?.surplusAllocation = .init(id: "envelope")
        changed.assistance?.transfers = [PlanTransfer(id: transferID, fromAccountID: "bank", toAccountID: "nre",
            sent: try PlanningAmount(money("100.00")), received: try PlanningAmount(money("2000.00", "INR")),
            date: "2026-11-20", conversionBasis: "1 QAR = 20 INR")]
        let receipt = try PlanningWriteReceiptContent.make(request: command, before: original, after: changed)
        XCTAssertEqual(receipt["created_record_ids"] as? [String], [transferID])
        let changes = try items(receipt, "changes")
        XCTAssertEqual(changes.count, 6)
        XCTAssertNotNil(item(changes, type: "transfer", field: "received"))
        let derived = try items(receipt, "derived_changes")
        XCTAssertNotNil(item(derived, type: "transfer", field: "sent"))
        XCTAssertEqual(item(derived, type: "allocation", field: "envelope_id")?["after"] as? String, "envelope")
    }

    func testRejectsOversizedDurableResultInsteadOfTruncating() throws {
        let original = try plan()
        let command = try request([["type": "transfer", "action": "create", "transfer_id": transferID,
                                    "fields": ["from_account_id": "bank", "to_account_id": "nre",
                                               "received": ["currency": "INR", "decimal": "2000.00"],
                                               "date": "2026-11-20", "funding_transfer_id": NSNull(),
                                               "required_india_funding": NSNull()]]])
        var changed = original
        changed.assistance?.transfers = [PlanTransfer(id: transferID, fromAccountID: "bank", toAccountID: "nre",
            sent: try PlanningAmount(money("100.00")), received: try PlanningAmount(money("2000.00", "INR")),
            date: "2026-11-20", conversionBasis: String(repeating: "x", count: 65_536))]
        XCTAssertThrowsError(try PlanningWriteReceiptContent.make(request: command, before: original, after: changed))
    }

    func testRemovalReportsIdentityAndClearedRootWithoutDeletedRowContent() throws {
        var original = try plan()
        original.assistance?.surplusAllocation = .init(id: "envelope", requiredIndiaTransferID: transferID)
        original.assistance?.transfers = [PlanTransfer(id: transferID, fromAccountID: "bank", toAccountID: "nre",
            sent: try PlanningAmount(money("100.00")), received: try PlanningAmount(money("2000.00", "INR")),
            date: "2026-11-20", conversionBasis: "owner rate")]
        let command = try request([["type": "remove_allocation", "kind": "transfer", "record_id": transferID]])
        var changed = original
        changed.assistance?.transfers = []
        changed.assistance?.surplusAllocation?.requiredIndiaTransferID = nil
        let receipt = try PlanningWriteReceiptContent.make(request: command, before: original, after: changed)
        XCTAssertEqual(receipt["removed_record_ids"] as? [String], [transferID])
        let changes = try items(receipt, "changes")
        XCTAssertEqual(changes.count, 1)
        XCTAssertTrue(changes[0]["after"] is NSNull)
        XCTAssertNil(changes[0]["before"])
        let derived = try items(receipt, "derived_changes")
        XCTAssertTrue(item(derived, type: "allocation_links", field: "required_india_transfer_id")?["after"] is NSNull)
        let encoded = try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys])
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("owner rate"))
    }
}
