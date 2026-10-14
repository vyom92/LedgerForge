import Foundation

/// Pure capture from one repository runtime projection and one public-cache
/// projection. This type performs no reads, writes, source application or seeding.
@MainActor
enum CompanionMacMonthContext {
    struct AccountInput {
        let repositoryAccountId: String?
        let workspaceId: String?
        let name: String
        let type: AccountType
        let nativeCurrency: CurrencyCode
        let status: AccountStatus
        let preferredDisplayName: String
        let selectionContext: String
        var isHistoryOnly: Bool { status == .closed }
    }

    static func make(scratchpad: MonthlyPlanScratchpad, metadata: MonthlyPlanSyncAdapter.Metadata,
                     runtime: RepositoryRuntimeSnapshot, cache: BackgroundPublicCacheSnapshot,
                     selectedHistoryAccountIDs: Set<String>) throws -> CompanionMonthAnchor {
        guard runtime.intelligence == nil || runtime.intelligence?.workspaceID == scratchpad.plan.workspaceID else {
            throw CompanionPacketError.invalid("The monthly source context belongs to a different workspace.")
        }
        let accounts = runtime.accounts.map {
            AccountInput(repositoryAccountId: $0.repositoryAccountId, workspaceId: $0.workspaceId,
                name: $0.name, type: $0.type, nativeCurrency: $0.nativeCurrency, status: $0.status,
                preferredDisplayName: $0.preferredDisplayName, selectionContext: $0.selectionContext)
        }
        return try make(scratchpad: scratchpad, metadata: metadata, accounts: accounts,
            manuallyExcludedPlanningAccountIDs: runtime.intelligence?.preferences?.excludedPlanningAccountIDs ?? [],
            receiptTransactions: runtime.transactions, latestAlDarQuote: cache.alDarLegs[.inr]?.planningQuote(),
            selectedHistoryAccountIDs: selectedHistoryAccountIDs)
    }

    static func make(scratchpad: MonthlyPlanScratchpad, metadata: MonthlyPlanSyncAdapter.Metadata,
                     accounts suppliedAccounts: [AccountInput], manuallyExcludedPlanningAccountIDs: Set<String>,
                     receiptTransactions: [Transaction], latestAlDarQuote: AlDarReferenceQuote?,
                     selectedHistoryAccountIDs: Set<String>) throws -> CompanionMonthAnchor {
        let plan = scratchpad.plan
        guard scratchpad.hasIdentity(workspaceID: plan.workspaceID, month: plan.month.canonical) else {
            throw CompanionPacketError.invalid("The monthly source context belongs to a different workspace.")
        }
        let accounts = suppliedAccounts.filter { $0.workspaceId == plan.workspaceID }
        var byID: [String: AccountInput] = [:]
        for account in accounts {
            guard let id = account.repositoryAccountId, !id.isEmpty,
                  byID.updateValue(account, forKey: id) == nil else {
                throw CompanionPacketError.invalid("The monthly account context has a missing or repeated repository identity.")
            }
        }
        let allHistory = Set(accounts.filter(\.isHistoryOnly).compactMap(\.repositoryAccountId))
        guard selectedHistoryAccountIDs.isSubset(of: allHistory) else {
            throw CompanionPacketError.invalid("A selected history account changed. Review the monthly account selection on the Mac.")
        }
        let excludedHistory = allHistory.subtracting(selectedHistoryAccountIDs)
        let manuallyExcluded = manuallyExcludedPlanningAccountIDs
        let excluded = manuallyExcluded.union(excludedHistory)
        func supportedCurrency(_ account: AccountInput) -> Bool { ["QAR", "INR"].contains(account.nativeCurrency.code) }
        func identified(_ account: AccountInput) -> String { account.repositoryAccountId! }
        func label(_ account: AccountInput) -> CompanionPlannerAccount {
            .init(id: identified(account), title: account.preferredDisplayName,
                  context: account.selectionContext, currency: account.nativeCurrency,
                  isHistoryOnly: account.isHistoryOnly)
        }
        func less(_ a: AccountInput, _ b: AccountInput) -> Bool {
            (a.nativeCurrency.code, a.name, identified(a)) < (b.nativeCurrency.code, b.name, identified(b))
        }
        // The Mac offers active banks plus explicit history-bank inclusion. The
        // phone applies the same manual exclusion and history-selection filters.
        let banks = accounts.filter {
            $0.type == .bank && supportedCurrency($0) && ($0.status == .active || $0.isHistoryOnly)
        }.sorted(by: less)
        let bankCurrencies = Dictionary(uniqueKeysWithValues: banks.map { (identified($0), $0.nativeCurrency) })
        let relatedCards = accounts.filter {
            let id = identified($0)
            return $0.type == .creditCard && supportedCurrency($0)
                && ($0.status == .active || selectedHistoryAccountIDs.contains(id)) && !excluded.contains(id)
        }.sorted(by: less)

        let rawBalanceIDs = Set(scratchpad.rawText.keys.filter { $0.hasPrefix("balance.") }.map { String($0.dropFirst("balance.".count)) })
            .union(scratchpad.fieldErrors.keys.filter { $0.hasPrefix("balance.") }.map { String($0.dropFirst("balance.".count)) })
            .union(scratchpad.unavailableBalanceAccountIDs)
        let retainedBankIDs = Set(plan.balances.map(\.accountID)).union(rawBalanceIDs)
        guard retainedBankIDs.isSubset(of: Set(bankCurrencies.keys)),
              plan.balances.allSatisfy({ bankCurrencies[$0.accountID] == $0.nativeCurrency && ($0.money == nil || $0.money?.currency == $0.nativeCurrency) }) else {
            throw CompanionPacketError.invalid("A retained planning balance has an unavailable account or changed native currency. Review it on the Mac.")
        }
        let bills = plan.qatarCommitments + plan.indiaCommitments
        var retainedFundingIDs = Set(bills.compactMap(\.fundingAccountID))
        retainedFundingIDs.formUnion(plan.assistance?.billFundingAccounts?.values ?? Dictionary<String, String>().values)
        if let salaryAccount = plan.assistance?.payslipFunding?.accountID { retainedFundingIDs.insert(salaryAccount) }
        for id in retainedFundingIDs {
            guard let account = byID[id], [.bank, .creditCard].contains(account.type), supportedCurrency(account) else {
                throw CompanionPacketError.invalid("A retained monthly funding account is missing, has a different role, or uses an unsupported currency.")
            }
        }
        for bill in bills {
            if let id = bill.fundingAccountID, byID[id]?.nativeCurrency != bill.money.currency {
                throw CompanionPacketError.invalid("A retained bill and its funding account have different native currencies.")
            }
            if let id = plan.assistance?.billFundingAccounts?[bill.id], byID[id]?.nativeCurrency != bill.money.currency {
                throw CompanionPacketError.invalid("A retained bill funding override has a different native currency.")
            }
        }
        if let salaryAccount = plan.assistance?.payslipFunding?.accountID {
            guard bankCurrencies[salaryAccount]?.code == "QAR" else {
                throw CompanionPacketError.invalid("The retained salary link does not identify a QAR bank in this workspace.")
            }
        }
        let fundingIDs = Set(relatedCards.map(identified)).union(retainedFundingIDs)
        let receipt = PayslipReceiptState.resolve(plan: plan, transactions: receiptTransactions, excludedAccounts: excluded)
        let quote = latestAlDarQuote
        var contextLines = ["Monthly plan " + plan.month.canonical + ".",
            "Recurring payment dates " + plan.recurringStart.canonical + "–" + plan.recurringEnd.canonical + "."]
        if let receipt { contextLines.append(receipt.explanation + ".") }
        let balanceDates = Set(plan.balances.compactMap { $0.financialBalanceDate?.canonical }).sorted()
        if !balanceDates.isEmpty { contextLines.append("Retained balance dates: " + balanceDates.joined(separator: ", ") + ".") }
        if let quote { contextLines.append("Public INR reference fetched " + quote.fetchedAtISO + ".") }
        return CompanionMonthAnchor(scratchpad: scratchpad, metadata: metadata,
            bankCurrencies: bankCurrencies, fundingAccountIDs: fundingIDs,
            excludedHistoryAccountIDs: excludedHistory,
            context: .init(accounts: banks.map(label), relatedCards: relatedCards.map(label),
                displayAccounts: accounts.filter { [.bank, .creditCard].contains($0.type) && supportedCurrency($0) }.sorted(by: less).map(label),
                allHistoryAccountIDs: allHistory, manuallyExcludedPlanningAccountIDs: manuallyExcluded,
                receipt: receipt.map(MonthlyPlanSyncAdapter.ReceiptProjection.init),
                receiptBasis: PlannerSalaryReceiptBasis(plan: plan, excludedAccounts: excluded),
                latestAlDarQuote: quote, sourceContext: contextLines.joined(separator: " ")))
    }

    /// Preserve the exact retained editor and lexical/order metadata. Only the
    /// independent account/source/quote context is recaptured from fresh inputs.
    static func refreshed(old: CompanionMonthAnchor, runtime: RepositoryRuntimeSnapshot,
                          cache: BackgroundPublicCacheSnapshot) throws -> CompanionMonthAnchor {
        let selectedHistory = old.context.allHistoryAccountIDs.subtracting(old.excludedHistoryAccountIDs)
        return try make(scratchpad: old.scratchpad, metadata: old.metadata,
                        runtime: runtime, cache: cache, selectedHistoryAccountIDs: selectedHistory)
    }
}
