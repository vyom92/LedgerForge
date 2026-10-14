import Foundation

extension MonthlyPlanSyncAdapter {
    /// Translate the editor's explicitly captured per-edit locale while preserving
    /// unknown historical origins. Call after every edit, before encode.
    static func metadata(for scratchpad: MonthlyPlanScratchpad, lexicalContext: PlannerLexicalContext,
                         retaining prior: Metadata, previousScratchpad: MonthlyPlanScratchpad? = nil) -> Metadata {
        let fields = Set(["fixed", "variable", "deductions", "fee", "investment", "reserve", "fx.rate"])
            .union(scratchpad.plan.deductions.map { "deduction.amount." + $0.id })
            .union((scratchpad.plan.qatarCommitments + scratchpad.plan.indiaCommitments).map { "amount." + $0.id })
            .union(scratchpad.plan.balances.map { "balance." + $0.accountID })
            .union(scratchpad.rawText.keys.filter { $0.hasPrefix("balance.") })
            .union(scratchpad.fieldErrors.keys.filter { $0.hasPrefix("balance.") })
            .union(scratchpad.unavailableBalanceAccountIDs.map { "balance." + $0 })
        func orderedItems(_ value: MonthlyPlanScratchpad) -> [(key: String, id: String, collection: String)] {
            let reverse = Dictionary(value.plan.assistance?.appliedRecurringIDs.map { ($0.value, $0.key) } ?? [], uniquingKeysWith: { first, _ in first })
            var rows = value.plan.deductions.map { (key: "deduction:" + $0.id, id: $0.id, collection: "deduction") }
            for (region, bills) in [("qatar", value.plan.qatarCommitments), ("india", value.plan.indiaCommitments)] {
                rows += bills.map { (key: reverse[$0.id].map { "recurring:" + $0 } ?? "bill:" + $0.id, id: $0.id, collection: region) }
            }
            rows += value.plan.balances.map { (key: "balance:" + $0.accountID, id: $0.id, collection: "balance") }
            return rows
        }
        let currentRows = orderedItems(scratchpad)
        var collections: [String: String] = [:]
        for row in orderedItems(previousScratchpad ?? scratchpad) + currentRows { collections[row.key] = row.collection }
        var maximum: [String: Int] = [:]
        for (key, order) in prior.order {
            if let collection = collections[key] {
                maximum[collection] = max(maximum[collection] ?? -1, order.position)
            } else if key.hasPrefix("deduction:") {
                maximum["deduction"] = max(maximum["deduction"] ?? -1, order.position)
            } else if key.hasPrefix("balance:") {
                maximum["balance"] = max(maximum["balance"] ?? -1, order.position)
            } else {
                // Older callers may not supply the deleted bill's prior region.
                // Reserve its position in both bill collections rather than reuse it.
                for collection in ["qatar", "india"] { maximum[collection] = max(maximum[collection] ?? -1, order.position) }
            }
        }
        var result = Metadata()
        for key in fields {
            if let identifier = lexicalContext.localeIdentifiersByField[key] ?? lexicalContext.defaultLocaleIdentifier {
                result.origins[key] = .known(localeIdentifier: identifier)
            } else { result.origins[key] = .unknown }
        }
        for row in currentRows {
            if let existing = prior.order[row.key] { result.order[row.key] = existing }
            else if previousScratchpad != nil {
                let last = maximum[row.collection] ?? -1
                // The codec rejects Int.max; do not overflow while retaining an error.
                let next = last == Int.max ? Int.max : last + 1
                result.order[row.key] = OrderKey(position: next, stableRowID: row.id)
                maximum[row.collection] = next
            }
        }
        return result
    }
    static func lexicalContext(from metadata: Metadata) -> PlannerLexicalContext {
        var known: [String: String] = [:]
        for (key, origin) in metadata.origins {
            if case let .known(identifier) = origin { known[key] = identifier }
        }
        return PlannerLexicalContext(defaultLocaleIdentifier: nil, localeIdentifiersByField: known)
    }
}
