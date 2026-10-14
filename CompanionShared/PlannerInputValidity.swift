import Foundation

nonisolated enum PlannerInputValidity {
    static func hasValidCalculation(plan: FundingPlan, fieldErrors: [String: String],
                                    excludedHistoryAccountIDs: Set<String>) -> Bool {
        let hidden = excludedHistoryAccountIDs
        let hiddenBills = Set((plan.qatarCommitments + plan.indiaCommitments).filter {
            !$0.isInAccountScope(excluding: hidden, fundingOverrides: plan.assistance?.billFundingAccounts)
        }.map(\.id))
        return fieldErrors.keys.allSatisfy { key in
            if key.hasPrefix("balance.") { return hidden.contains(String(key.dropFirst("balance.".count))) }
            for prefix in ["amount.", "label."] where key.hasPrefix(prefix) {
                return hiddenBills.contains(String(key.dropFirst(prefix.count)))
            }
            return false
        }
        }
}
