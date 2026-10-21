import Foundation

/// Produces one candidate from an existing canonical plan. The caller owns the
/// repository revision check and atomic save; this type never writes a ledger.
nonisolated enum PlanningChangeApplicator {
    static func apply(_ changes: [PlanningChange], to original: FundingPlan,
                      snapshot: FinancialIntelligenceSnapshot, accounts: [AccountDTO],
                      productLabels: [String: [String]] = [:],
                      salaryReceipt: PayslipReceiptState? = nil) throws -> FundingPlan {
        guard original.calculationVersion == .budgetV1, original.workspaceID == snapshot.workspaceID,
              (1...32).contains(changes.count) else { throw PlanningChangeError.invalid("plan") }
        var plan = original
        var assignments: Set<String> = []
        enum RowOperation: Equatable { case create, update, remove }
        var rowActions: [String: RowOperation] = [:]
        var repricedTransferIDs: Set<String> = []
        var fxChanged = false
        let originalTransferIDs = Set((original.assistance?.transfers ?? []).map(\.id))

        func assign(_ key: String) throws {
            guard assignments.insert(key).inserted else { throw PlanningChangeError.duplicateAssignment(key) }
        }
        func markRow(_ key: String, action: PlanningAllocationAction?) throws {
            let next: RowOperation = if let action { action == .create ? .create : .update } else { .remove }
            if let prior = rowActions[key] {
                guard prior == .update && next == .update else {
                    throw PlanningChangeError.conflictingRow(key)
                }
            }
            rowActions[key] = next
        }
        func require(_ condition: Bool, _ path: String) throws {
            guard condition else { throw PlanningChangeError.invalid(path) }
        }
        func positiveOrZero(_ amount: PlanningMoney, currency: String, path: String) throws -> Money {
            try require(amount.currency == currency && amount.money.amount >= 0, path)
            return amount.money
        }
        func nonnull<T: Sendable>(_ patch: PlanningPatch<T>, _ path: String) throws -> T? {
            switch patch {
            case .omitted: return nil
            case .null: throw PlanningChangeError.invalid(path)
            case .value(let value): return value
            }
        }
        func optionalID(_ patch: PlanningPatch<String>, current: String?) -> String? {
            switch patch {
            case .omitted: current
            case .null: nil
            case .value(let value): value
            }
        }
        func allocation() {
            if plan.assistance == nil { plan.assistance = .init(workspaceID: plan.workspaceID, month: plan.month.canonical) }
            if plan.assistance?.surplusAllocation == nil {
                plan.assistance?.surplusAllocation = .init(id: UUID().uuidString)
            }
        }

        for change in changes {
            switch change {
            case let .monthlyAmount(field, amount):
                try assign("monthly.\(field.rawValue)")
                try require(amount.currency == "QAR", "monthly.\(field.rawValue)")
                switch field {
                case .expectedFixed:
                    plan.expectedFixedEarnings = amount.money; plan.expectedFixedProvenance = .manual
                case .expectedVariable:
                    plan.expectedVariableEarnings = amount.money; plan.expectedVariableProvenance = .manual
                case .configuredTransferFee:
                    plan.configuredTransferFee = try positiveOrZero(amount, currency: "QAR", path: "configured_transfer_fee")
                    plan.configuredTransferFeeProvenance = .manual
                case .keepInCBQ:
                    plan.keepInCBQ = try positiveOrZero(amount, currency: "QAR", path: "keep_in_cbq")
                }
            case let .deductionAmount(id, amount):
                try assign("deduction.\(id)")
                guard let index = plan.deductions.firstIndex(where: { $0.id == id }) else { throw PlanningChangeError.invalid("deduction_id") }
                plan.deductions[index].money = try positiveOrZero(amount, currency: "QAR", path: "deduction.amount")
            case let .obligation(region, id, fields):
                let key = "obligation.\(region.rawValue).\(id)"
                var rows = region == .qatar ? plan.qatarCommitments : plan.indiaCommitments
                guard let index = rows.firstIndex(where: { $0.id == id }) else { throw PlanningChangeError.invalid("obligation_id") }
                if fields.amount.isSupplied {
                    try assign(key + ".amount")
                    if let amount = try nonnull(fields.amount, key + ".amount") {
                        rows[index].money = try positiveOrZero(amount, currency: region == .qatar ? "QAR" : "INR", path: key + ".amount")
                        if let basis = rows[index].temporaryCarryBasis {
                            try require(rows[index].money.amount <= basis.amount, key + ".temporary_carry_basis")
                        }
                    }
                }
                if fields.dueDate.isSupplied {
                    try assign(key + ".due_date")
                    switch fields.dueDate {
                    case .omitted: break
                    case .null:
                        try require(plan.assistance?.appliedRecurringIDs.values.contains(id) != true, key + ".due_date")
                        rows[index].dueDate = nil
                    case .value(let date):
                        if plan.assistance?.appliedRecurringIDs.values.contains(id) == true {
                            try require(plan.includesRecurring(date), key + ".due_date")
                        }
                        rows[index].dueDate = date
                    }
                    plan.assistance?.carriedBillDates?[id] = nil
                }
                if let included = try nonnull(fields.included, key + ".included") {
                    try assign(key + ".included"); rows[index].included = included
                }
                if fields.payingAccountID.isSupplied {
                    try assign(key + ".paying_account_id")
                    if plan.assistance == nil { plan.assistance = .init(workspaceID: plan.workspaceID, month: plan.month.canonical) }
                    if plan.assistance?.billFundingAccounts == nil { plan.assistance?.billFundingAccounts = [:] }
                    let current = plan.assistance?.billFundingAccounts?[id]
                    plan.assistance?.billFundingAccounts?[id] = optionalID(fields.payingAccountID,
                        current: current)
                }
                if region == .qatar { plan.qatarCommitments = rows } else { plan.indiaCommitments = rows }
            case let .planningBalance(id, accountID, fields):
                guard let index = plan.balances.firstIndex(where: { $0.id == id && $0.accountID == accountID }) else {
                    throw PlanningChangeError.invalid("planning_balance")
                }
                let key = "balance.\(id)"
                if let amount = try nonnull(fields.amount, key + ".amount") {
                    try assign(key + ".amount")
                    try require(amount.currency == plan.balances[index].nativeCurrency.code, key + ".amount")
                    plan.balances[index].money = amount.money
                    plan.balances[index].provenance = .manual
                    plan.balances[index].financialBalanceDate = nil
                }
                if let included = try nonnull(fields.included, key + ".included") {
                    try assign(key + ".included"); plan.balances[index].included = included
                }
            case let .manualFX(rate, date):
                try assign("manual_fx")
                plan.planningFX = try FundingPlanFX(inrPerQAR: rate, observationDate: date)
                plan.referenceMode = .manual
                plan.effectiveAlDarReference = nil
                fxChanged = true
            case let .contribution(action, id, fields):
                let rowKey = "contribution.\(id)"
                try markRow(rowKey, action: action)
                for (field, supplied) in [("amount", fields.amount.isSupplied), ("date", fields.date.isSupplied),
                    ("funding_account_id", fields.fundingAccountID.isSupplied),
                    ("funding_transfer_id", fields.fundingTransferID.isSupplied)] where supplied {
                    try assign(rowKey + "." + field)
                }
                allocation()
                let existing = plan.assistance!.contributions.firstIndex(where: { $0.id == id })
                if action == .create {
                    try require(existing == nil && snapshot.reserves.contains(where: { $0.id == id && $0.workspaceID == plan.workspaceID }), "designation_id")
                    guard let amount = try nonnull(fields.amount, "contribution.amount"),
                          let date = try nonnull(fields.date, "contribution.date"),
                          let bank = try nonnull(fields.fundingAccountID, "contribution.funding_account_id") else {
                        throw PlanningChangeError.missing("contribution.fields")
                    }
                    let currency = snapshot.reserves.first { $0.id == id }!.target.currency
                    _ = try positiveOrZero(amount, currency: currency, path: "contribution.amount")
                    plan.assistance?.contributions.append(.init(designationID: id, fundingAccountID: bank,
                        amount: try PlanningAmount(amount.money), dueDate: date.canonical,
                        fundingTransferID: optionalID(fields.fundingTransferID, current: nil)))
                } else {
                    guard let index = existing else { throw PlanningChangeError.invalid("designation_id") }
                    if let amount = try nonnull(fields.amount, "contribution.amount") {
                        let currency = plan.assistance!.contributions[index].amount.currency
                        _ = try positiveOrZero(amount, currency: currency, path: "contribution.amount")
                        plan.assistance?.contributions[index].amount = try PlanningAmount(amount.money)
                    }
                    if let date = try nonnull(fields.date, "contribution.date") { plan.assistance?.contributions[index].dueDate = date.canonical }
                    if let bank = try nonnull(fields.fundingAccountID, "contribution.funding_account_id") { plan.assistance?.contributions[index].fundingAccountID = bank }
                    if fields.fundingTransferID.isSupplied {
                        let current = plan.assistance?.contributions[index].fundingTransferID
                        plan.assistance?.contributions[index].fundingTransferID = optionalID(fields.fundingTransferID,
                            current: current)
                    }
                }
            case let .transfer(action, id, fields):
                let rowKey = "transfer.\(id)"
                try markRow(rowKey, action: action)
                for (field, supplied) in [("from_account_id", fields.fromAccountID.isSupplied),
                    ("to_account_id", fields.toAccountID.isSupplied), ("received", fields.received.isSupplied),
                    ("date", fields.date.isSupplied), ("funding_transfer_id", fields.fundingTransferID.isSupplied),
                    ("required_india_funding", fields.requiredIndiaFunding.isSupplied)] where supplied {
                    try assign(rowKey + "." + field)
                }
                allocation()
                let existing = plan.assistance!.transfers?.firstIndex(where: { $0.id == id })
                if action == .create {
                    try require(existing == nil && UUID(uuidString: id) != nil, "transfer_id")
                    guard let from = try nonnull(fields.fromAccountID, "transfer.from_account_id"),
                          let to = try nonnull(fields.toAccountID, "transfer.to_account_id"),
                          let received = try nonnull(fields.received, "transfer.received"),
                          let date = try nonnull(fields.date, "transfer.date") else {
                        throw PlanningChangeError.missing("transfer.fields")
                    }
                    let source = try account(from, in: accounts, workspaceID: plan.workspaceID)
                    _ = try positiveOrZero(received, currency: try account(to, in: accounts, workspaceID: plan.workspaceID).nativeCurrency, path: "transfer.received")
                    if plan.assistance?.transfers == nil { plan.assistance?.transfers = [] }
                    plan.assistance?.transfers?.append(.init(id: id, fromAccountID: from, toAccountID: to,
                        sent: .init(currency: source.nativeCurrency, decimal: "0"), received: try PlanningAmount(received.money),
                        date: date.canonical, conversionBasis: "", fundingTransferID: optionalID(fields.fundingTransferID, current: nil),
                        requiredIndiaFunding: try nullableAmount(fields.requiredIndiaFunding)))
                    repricedTransferIDs.insert(id)
                } else {
                    guard let index = existing else { throw PlanningChangeError.invalid("transfer_id") }
                    guard plan.assistance?.transfers?[index].transactionIDs?.isEmpty ?? true else { throw PlanningChangeError.invalid("transfer.actual_links") }
                    var transfer = plan.assistance!.transfers![index]
                    if let from = try nonnull(fields.fromAccountID, "transfer.from_account_id") { transfer.fromAccountID = from; repricedTransferIDs.insert(id) }
                    if let to = try nonnull(fields.toAccountID, "transfer.to_account_id") { transfer.toAccountID = to }
                    if let received = try nonnull(fields.received, "transfer.received") {
                        _ = try positiveOrZero(received, currency: try account(transfer.toAccountID, in: accounts, workspaceID: plan.workspaceID).nativeCurrency, path: "transfer.received")
                        transfer.received = try PlanningAmount(received.money); repricedTransferIDs.insert(id)
                    }
                    if let date = try nonnull(fields.date, "transfer.date") { transfer.date = date.canonical }
                    if fields.fundingTransferID.isSupplied { transfer.fundingTransferID = optionalID(fields.fundingTransferID, current: transfer.fundingTransferID) }
                    if fields.requiredIndiaFunding.isSupplied { transfer.requiredIndiaFunding = try nullableAmount(fields.requiredIndiaFunding) }
                    plan.assistance?.transfers?[index] = transfer
                }
            case let .investment(action, id, fields):
                let rowKey = "investment.\(id)"
                try markRow(rowKey, action: action)
                for (field, supplied) in [("instrument", fields.instrument.isSupplied),
                    ("funding_account_id", fields.fundingAccountID.isSupplied), ("amount", fields.amount.isSupplied),
                    ("date", fields.date.isSupplied), ("funding_transfer_id", fields.fundingTransferID.isSupplied)] where supplied {
                    try assign(rowKey + "." + field)
                }
                allocation()
                let existing = plan.assistance!.surplusAllocation!.investments.firstIndex(where: { $0.id == id })
                if action == .create {
                    try require(existing == nil && UUID(uuidString: id) != nil, "investment_id")
                    guard let instrument = try nonnull(fields.instrument, "investment.instrument"),
                          let bank = try nonnull(fields.fundingAccountID, "investment.funding_account_id"),
                          let amount = try nonnull(fields.amount, "investment.amount"),
                          let date = try nonnull(fields.date, "investment.date") else {
                        throw PlanningChangeError.missing("investment.fields")
                    }
                    let source = try account(bank, in: accounts, workspaceID: plan.workspaceID)
                    _ = try positiveOrZero(amount, currency: source.nativeCurrency, path: "investment.amount")
                    let selected = instrument.native
                    try selected.validated(fundingCurrency: source.nativeCurrency)
                    plan.assistance?.surplusAllocation?.investments.append(.init(id: id, instrument: selected,
                        fundingAccountID: bank, amount: try PlanningAmount(amount.money), date: date.canonical,
                        fundingTransferID: optionalID(fields.fundingTransferID, current: nil)))
                } else {
                    guard let index = existing else { throw PlanningChangeError.invalid("investment_id") }
                    var row = plan.assistance!.surplusAllocation!.investments[index]
                    if let instrument = try nonnull(fields.instrument, "investment.instrument") {
                        try require(instrument.isIBKR == row.instrument.isIBKR, "investment.instrument")
                        row.instrument = instrument.native
                    }
                    if let bank = try nonnull(fields.fundingAccountID, "investment.funding_account_id") { row.fundingAccountID = bank }
                    if let amount = try nonnull(fields.amount, "investment.amount") { row.amount = try PlanningAmount(amount.money) }
                    if let date = try nonnull(fields.date, "investment.date") { row.date = date.canonical }
                    if fields.fundingTransferID.isSupplied { row.fundingTransferID = optionalID(fields.fundingTransferID, current: row.fundingTransferID) }
                    let source = try account(row.fundingAccountID, in: accounts, workspaceID: plan.workspaceID)
                    let money = try row.amount.money()
                    try require(money.currency.code == source.nativeCurrency && money.amount >= 0, "investment.amount")
                    try row.instrument.validated(fundingCurrency: source.nativeCurrency)
                    plan.assistance?.surplusAllocation?.investments[index] = row
                }
            case let .allocationLinks(fields):
                allocation()
                if fields.requiredIndiaTransferID.isSupplied {
                    try assign("allocation.required_india_transfer_id")
                    let current = plan.assistance?.surplusAllocation?.requiredIndiaTransferID
                    plan.assistance?.surplusAllocation?.requiredIndiaTransferID = optionalID(fields.requiredIndiaTransferID,
                        current: current)
                }
                if fields.keepInCBQDesignationID.isSupplied {
                    try assign("allocation.keep_in_cbq_designation_id")
                    let current = plan.assistance?.surplusAllocation?.keepInCBQDesignationID
                    plan.assistance?.surplusAllocation?.keepInCBQDesignationID = optionalID(fields.keepInCBQDesignationID,
                        current: current)
                }
            case let .removeAllocation(kind, id):
                try markRow("\(kind.rawValue).\(id)", action: nil)
                guard plan.assistance?.surplusAllocation != nil else { throw PlanningChangeError.invalid("remove_allocation") }
                switch kind {
                case .contribution:
                    guard plan.assistance?.contributions.contains(where: { $0.id == id }) == true else { throw PlanningChangeError.invalid("record_id") }
                    plan.assistance?.contributions.removeAll { $0.id == id }
                    if plan.assistance?.surplusAllocation?.keepInCBQDesignationID == id { plan.assistance?.surplusAllocation?.keepInCBQDesignationID = nil }
                case .transfer:
                    guard let row = plan.assistance?.transfers?.first(where: { $0.id == id }), row.transactionIDs?.isEmpty ?? true else { throw PlanningChangeError.invalid("record_id") }
                    plan.assistance?.transfers?.removeAll { $0.id == id }
                    if plan.assistance?.surplusAllocation?.requiredIndiaTransferID == id { plan.assistance?.surplusAllocation?.requiredIndiaTransferID = nil }
                case .investment:
                    guard plan.assistance?.surplusAllocation?.investments.contains(where: { $0.id == id }) == true else { throw PlanningChangeError.invalid("record_id") }
                    plan.assistance?.surplusAllocation?.investments.removeAll { $0.id == id }
                }
            }
        }

        // A final-state pass permits forward references while leaving all old
        // actual-linked intentions and source facts untouched.
        for index in plan.assistance?.transfers?.indices ?? 0..<0 {
            var row = plan.assistance!.transfers![index]
            let source = try account(row.fromAccountID, in: accounts, workspaceID: plan.workspaceID)
            let destination = try account(row.toAccountID, in: accounts, workspaceID: plan.workspaceID)
            let received = try row.received.money()
            try require(received.currency.code == destination.nativeCurrency && received.amount >= 0, "transfer.received")
            guard let sent = FundingPlanCalculator.transferPrincipal(received: received, fromCurrency: source.nativeCurrency, plan: plan) else {
                throw PlanningChangeError.invalid("transfer.fx")
            }
            if repricedTransferIDs.contains(row.id) {
                row.sent = try PlanningAmount(sent)
                row.conversionBasis = source.nativeCurrency == destination.nativeCurrency
                    ? "Same-currency own-account transfer" : plan.referenceMode == .manual
                        ? "Month-local manual rate" : "Month-local Al Dar reference"
                plan.assistance?.transfers?[index] = row
            } else if fxChanged && originalTransferIDs.contains(row.id) {
                try require(row.sent == (try PlanningAmount(sent)), "transfer.\(row.id).requires_explicit_repricing")
            }
        }
        let dto = try plan.persistenceDTO()
        try SalaryPersistenceDTOValidator.validate(plan: dto)
        try PlanningMetadataValidation.validatePlanLinks(dto, snapshot: snapshot)
        try PlanningMetadataValidation.validateFunding(dto, accounts: accounts)
        if plan.assistance?.surplusAllocation != nil {
            let result = try SurplusAllocationCalculator.calculate(plan: plan, reserves: snapshot.reserves,
                accounts: accounts, productLabels: productLabels, preferences: snapshot.preferences,
                salaryReceipt: salaryReceipt)
            try SurplusAllocationCalculator.validatePublication(result, plan: plan, accounts: accounts,
                preferences: snapshot.preferences)
        } else {
            try SurplusAllocationCalculator.validateUnallocatedKeep(plan: plan, accounts: accounts,
                preferences: snapshot.preferences, salaryReceipt: salaryReceipt)
        }
        return plan
    }

    private static func account(_ id: String, in accounts: [AccountDTO], workspaceID: String) throws -> AccountDTO {
        guard let account = accounts.first(where: { $0.id == id && $0.workspaceId == workspaceID && $0.accountType == "bank" && $0.closedAtISO == nil }) else {
            throw PlanningChangeError.invalid("funding_account_id")
        }
        return account
    }

    private static func nullableAmount(_ patch: PlanningPatch<PlanningMoney>) throws -> PlanningAmount? {
        switch patch {
        case .omitted, .null: return nil
        case .value(let amount):
            guard amount.currency == "INR", amount.money.amount >= 0 else { throw PlanningChangeError.invalid("required_india_funding") }
            return try PlanningAmount(amount.money)
        }
    }
}

private extension PlanningInstrument {
    nonisolated var native: PlannedInvestmentInstrument {
        switch self {
        case let .ibkr(conid, title, quoteCurrency): .ibkr(conid: conid, title: title, quoteCurrency: quoteCurrency)
        case let .indianMutualFund(schemeCode, title): .indianMutualFund(schemeCode: schemeCode, title: title)
        }
    }
    nonisolated var isIBKR: Bool {
        if case .ibkr = self { return true }
        return false
    }
}

private extension PlannedInvestmentInstrument {
    nonisolated var isIBKR: Bool {
        if case .ibkr = self { return true }
        return false
    }
}
