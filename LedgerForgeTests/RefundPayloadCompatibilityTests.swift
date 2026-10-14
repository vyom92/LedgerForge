import Foundation
import Testing
@testable import LedgerForge

/// These are nonfinancial metadata codec checks. Authentic transactions,
/// allocations and source-fee expectations belong to the populated gate.
struct RefundPayloadCompatibilityTests {
    private func legacyMetadata() -> [String: Any] {
        ["id": "metadata-event", "workspaceID": "metadata-workspace", "kind": "refund",
         "decision": "rejected", "transactionIDs": [String](), "explanation": "Codec compatibility",
         "reviewedAtISO": "2026-01-01T00:00:00Z"]
    }

    @Test func absentOptionalMovementFieldsDecodeWithoutInventingAllocations() throws {
        let data = try JSONSerialization.data(withJSONObject: legacyMetadata())
        let value = try JSONDecoder().decode(MovementEvent.self, from: data)
        #expect(value.consumptionTransactionIDs.isEmpty)
        #expect(value.refundAllocations == nil)
        #expect(value.transactionIDs.isEmpty)
        #expect(value.decision == .rejected)
        let encoded = try JSONEncoder().encode(value)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object["refundAllocations"] == nil)
        #expect(try JSONDecoder().decode(MovementEvent.self, from: encoded) == value)
    }

    @Test func explicitEmptyAndMissingAllocationMetadataStayDistinct() throws {
        var payload = legacyMetadata()
        payload["consumptionTransactionIDs"] = [String]()
        payload["refundAllocations"] = [Any]()
        let value = try JSONDecoder().decode(MovementEvent.self, from: JSONSerialization.data(withJSONObject: payload))
        #expect(value.refundAllocations == [])
        let missing = try JSONDecoder().decode(MovementEvent.self, from: JSONSerialization.data(withJSONObject: legacyMetadata()))
        #expect(value != missing)
    }

    @Test func malformedOptionalAllocationMetadataFailsDecoding() throws {
        var payload = legacyMetadata()
        payload["refundAllocations"] = ["unexpected": "object"]
        let data = try JSONSerialization.data(withJSONObject: payload)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(MovementEvent.self, from: data) }
    }
}
