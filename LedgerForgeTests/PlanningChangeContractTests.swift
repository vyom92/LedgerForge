import Foundation
import Testing
@testable import LedgerForge

struct PlanningChangeContractTests {
    private let requestID = "68cb8090-3f23-4bca-97d8-7c6b60023f63"
    private let transferID = "a966b69a-84b4-4523-aa95-14c8909ff67d"
    private let investmentID = "e31097d0-91a2-49f1-8a64-cbbfc772f423"

    private func money(_ decimal: String, _ currency: String = "QAR") -> [String: Any] {
        ["currency": currency, "decimal": decimal]
    }

    private func request(_ changes: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "request_id": requestID,
            "workspace_id": "workspace",
            "month": "2026-11",
            "plan_id": "plan",
            "expected_write_revision": "planning-write-v1:" + String(repeating: "a", count: 64),
            "changes": changes
        ], options: [.sortedKeys])
    }

    @Test func decodesEveryClosedChangeFamilyAndPreservesNullablePatches() throws {
        let changes: [[String: Any]] = [
            ["type": "monthly_amount", "field": "expected_fixed", "amount": money("-100.00")],
            ["type": "deduction_amount", "deduction_id": "deduction", "amount": money("10.00")],
            ["type": "obligation", "region": "india", "obligation_id": "bill", "fields": ["due_date": NSNull(), "paying_account_id": NSNull()]],
            ["type": "planning_balance", "balance_id": "balance", "account_id": "account", "fields": ["included": true]],
            ["type": "manual_fx", "inr_per_qar": "23.4567", "observation_date": "2026-11-01"],
            ["type": "contribution", "action": "create", "designation_id": "reserve", "fields": [
                "amount": money("100.00"), "date": "2026-11-10", "funding_account_id": "bank", "funding_transfer_id": NSNull()]],
            ["type": "transfer", "action": "create", "transfer_id": transferID, "fields": [
                "from_account_id": "bank", "to_account_id": "nre", "received": money("1000.00", "INR"),
                "date": "2026-11-10", "funding_transfer_id": NSNull(), "required_india_funding": NSNull()]],
            ["type": "investment", "action": "create", "investment_id": investmentID, "fields": [
                "instrument": ["kind": "ibkr", "conid": "123456", "title": "Example ETF", "quote_currency": "USD"],
                "funding_account_id": "bank", "amount": money("50.00"), "date": "2026-11-11",
                "funding_transfer_id": transferID]],
            ["type": "allocation_links", "fields": ["required_india_transfer_id": transferID]],
            ["type": "remove_allocation", "kind": "investment", "record_id": "old-investment"]
        ]
        let decoded = try PlanningChangeRequest.decode(request(changes))
        #expect(decoded.changes.count == 10)
        guard case .obligation(_, _, let obligation) = decoded.changes[2] else { Issue.record("Wrong obligation case"); return }
        guard case .null = obligation.dueDate else { Issue.record("Date null was lost"); return }
        guard case .omitted = obligation.amount else { Issue.record("Omitted amount was lost"); return }
        guard case .value(true) = (decoded.changes[3].balanceFields?.included ?? .omitted) else {
            Issue.record("Included patch was lost"); return
        }
        #expect(try PlanningChangeRequest.decode(decoded.canonicalData()).digestSHA256() == decoded.digestSHA256())
    }

    @Test func rejectsUnknownKeysInvalidMoneyAndImpossibleCivilDates() throws {
        let valid: [String: Any] = ["type": "monthly_amount", "field": "keep_in_cbq", "amount": money("1.00")]
        let unknown = ["type": "monthly_amount", "field": "keep_in_cbq", "amount": ["currency": "QAR", "decimal": "1.00", "source": "invented"]] as [String: Any]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([unknown])) }
        for decimal in ["-0.00", "1.0", "1e2", "1,000.00", "92233720368547758.08", "-1.00"] {
            var change = valid
            change["amount"] = money(decimal)
            #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([change])) }
        }
        let impossible: [String: Any] = ["type": "manual_fx", "inr_per_qar": "23.1", "observation_date": "2026-02-30"]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([impossible])) }
        let wrongCurrency: [String: Any] = ["type": "obligation", "region": "india", "obligation_id": "bill", "fields": ["amount": money("100.00", "QAR")]]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([wrongCurrency])) }
        let forbiddenNull: [String: Any] = ["type": "planning_balance", "balance_id": "b", "account_id": "a", "fields": ["included": NSNull()]]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([forbiddenNull])) }
        let extra: [String: Any] = ["type": "planning_balance", "balance_id": "b", "account_id": "a", "fields": ["included": true, "provenance": "manual"]]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([extra])) }
    }

    @Test func creationRequiresStableIdentityAndCompleteFields() throws {
        let transfer: [String: Any] = ["type": "transfer", "action": "create", "transfer_id": transferID,
                                       "fields": ["from_account_id": "bank"]]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([transfer])) }
        let zeroConid: [String: Any] = ["type": "investment", "action": "create", "investment_id": investmentID,
                                        "fields": ["instrument": ["kind": "ibkr", "conid": "000", "title": "ETF", "quote_currency": "USD"],
                                                   "funding_account_id": "bank", "amount": money("1.00"), "date": "2026-11-01", "funding_transfer_id": NSNull()]]
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([zeroConid])) }
        var invalidID = zeroConid
        invalidID["investment_id"] = "not-a-uuid"
        #expect(throws: PlanningChangeError.self) { try PlanningChangeRequest.decode(request([invalidID])) }
    }

    @Test func duplicateAssignmentsAndRowOperationConflictsReject() throws {
        let first: [String: Any] = ["type": "obligation", "region": "qatar", "obligation_id": "bill", "fields": ["amount": money("10.00")]]
        let second: [String: Any] = ["type": "obligation", "region": "qatar", "obligation_id": "bill", "fields": ["amount": money("11.00")]]
        #expect(throws: PlanningChangeError.duplicateAssignment("obligation.qatar.bill.amount")) {
            try PlanningChangeRequest.decode(request([first, second]))
        }
        let update: [String: Any] = ["type": "transfer", "action": "update", "transfer_id": transferID, "fields": ["date": "2026-11-01"]]
        let remove: [String: Any] = ["type": "remove_allocation", "kind": "transfer", "record_id": transferID]
        #expect(throws: PlanningChangeError.conflictingRow("transfer." + transferID)) {
            try PlanningChangeRequest.decode(request([update, remove]))
        }
        let disjoint: [String: Any] = ["type": "obligation", "region": "qatar", "obligation_id": "bill", "fields": ["included": true]]
        #expect(try PlanningChangeRequest.decode(request([first, disjoint])).changes.count == 2)
    }

    @Test func schemaAndDigestAreStableAcrossObjectKeyOrder() throws {
        let tool = try PlanningWriteToolSchema.toolDefinition
        #expect(tool["name"] as? String == "apply_planning_changes")
        let schema = try #require(tool["inputSchema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)
        let changes: [[String: Any]] = [["type": "monthly_amount", "field": "expected_variable", "amount": money("1.00")]]
        let compact = try request(changes)
        let reordered = Data(("{\"changes\":[{\"amount\":{\"decimal\":\"1.00\",\"currency\":\"QAR\"},\"field\":\"expected_variable\",\"type\":\"monthly_amount\"}],\"plan_id\":\"plan\",\"request_id\":\"" + requestID + "\",\"month\":\"2026-11\",\"workspace_id\":\"workspace\",\"expected_write_revision\":\"planning-write-v1:" + String(repeating: "a", count: 64) + "\"}").utf8)
        #expect(try PlanningChangeRequest.decode(compact).digestSHA256() == PlanningChangeRequest.decode(reordered).digestSHA256())
    }
}

private extension PlanningChange {
    var balanceFields: PlanningBalanceFields? {
        guard case .planningBalance(_, _, let fields) = self else { return nil }
        return fields
    }
}
