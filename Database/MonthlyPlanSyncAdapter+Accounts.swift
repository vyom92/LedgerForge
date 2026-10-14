import Foundation

/// Mac target only. Invoke with the rows read inside the receive/commit transaction.
extension MonthlyPlanSyncAdapter.Binding {
    nonisolated func validateAccounts(_ accounts: [AccountDTO], editor: MonthlyPlanScratchpad? = nil) throws {
        let workspace = baselineScratchpad.plan.workspaceID
        var actual: [String: AccountDTO] = [:]
        for account in accounts where account.workspaceId == workspace {
            guard actual.updateValue(account, forKey: account.id) == nil else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Duplicate account identity")
            }
        }
        for (id, currency) in bankCurrencies {
            guard let row = actual[id], row.accountType == "bank", row.nativeCurrency == currency.code else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Planning bank identity or currency changed")
            }
        }
        for id in fundingAccountIDs {
            guard let row = actual[id], ["bank", "credit_card", "creditCard"].contains(row.accountType ?? "") else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Bill funding account is outside the workspace")
            }
        }
        for id in excludedHistoryAccountIDs {
            guard let row = actual[id], row.closedAtISO != nil else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("History account selection changed")
            }
        }
        let scratchpad = editor ?? baselineScratchpad
        guard scratchpad.hasIdentity(workspaceID: workspace, month: scope.month) else {
            throw MonthlyPlanSyncAdapter.AdapterError.identity
        }
        for balance in scratchpad.plan.balances {
            guard bankCurrencies[balance.accountID] == balance.nativeCurrency,
                  balance.money == nil || balance.money?.currency == balance.nativeCurrency else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Balance account or currency mismatch")
            }
        }
        let rows = scratchpad.plan.qatarCommitments + scratchpad.plan.indiaCommitments
        for row in rows {
            if let id = row.fundingAccountID, !fundingAccountIDs.contains(id) {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Unknown bill funding account")
            }
        }
        for id in scratchpad.plan.assistance?.billFundingAccounts?.values ?? Dictionary<String, String>().values {
            guard fundingAccountIDs.contains(id) else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Unknown funding override")
            }
        }
        if let link = scratchpad.plan.assistance?.payslipFunding {
            guard bankCurrencies[link.accountID] != nil else {
                throw MonthlyPlanSyncAdapter.AdapterError.structure("Unknown salary-linked bank")
            }
        }
    }
}
