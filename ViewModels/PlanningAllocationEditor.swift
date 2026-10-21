import Foundation

nonisolated enum AllocationRowID: Hashable, Identifiable {
    case retention
    case contribution(String)
    case transfer(String)
    case investment(String)

    var id: String {
        switch self {
        case .retention: "retention"
        case .contribution(let id): "contribution." + id
        case .transfer(let id): "transfer." + id
        case .investment(let id): "investment." + id
        }
    }
    func fieldKey(_ field: AllocationEditorField) -> String { "allocation." + id + "." + field.rawValue }
    var fieldPrefix: String { "allocation." + id + "." }
}

nonisolated enum AllocationEditorField: String {
    case amount, received, date, instrumentID, instrumentTitle, quoteCurrency, requiredIndiaFunding
    case fundingAccount, destinationAccount, fundingTransfer
}

nonisolated enum AllocationInvestmentKind { case ibkr, indianMutualFund }

nonisolated enum AllocationPlanningStatus: Equatable {
    case approvedInPlan, pending, incompleteEntry, needsReview, couldNotSave, existingChoice
    var title: String {
        switch self {
        case .approvedInPlan: "Approved in plan"
        case .pending: "Keeping changes…"
        case .incompleteEntry: "Incomplete entry"
        case .needsReview: "Needs review"
        case .couldNotSave: "Could not save"
        case .existingChoice: "Existing monthly choice"
        }
    }
}

nonisolated struct AllocationEditorRow: Identifiable {
    let id: AllocationRowID
    let kind: String
    let date: String?
    let sourceAccountID: String?
    let destination: String
    let amount: PlanningAmount?
    let received: PlanningAmount?
    let purpose: String
}

extension SalaryWorkspaceViewModel {
    var allocationReserves: [ReserveDesignation] { allocationMetadata?.reserves ?? [] }
    var allocationAccounts: [IntelligenceAccountContext] {
        allocationSourceContext.accounts.filter {
            $0.domain == "bank" && !$0.isHistoryOnly && ["QAR", "INR"].contains($0.currency)
                && !excludedPlanningAccountIDs.contains($0.id)
        }
    }
    var allocationResult: Result<SurplusAllocationCalculation, SurplusAllocationError>? {
        guard plan.assistance?.surplusAllocation != nil else { return nil }
        guard hasValidCalculation else { return .failure(.incompletePlan) }
        guard let metadata = allocationMetadata else { return .failure(.incompletePlan) }
        // Route roles are source-owned hydration results, never editable names.
        let labels = Dictionary(uniqueKeysWithValues: allocationSourceContext.accounts.compactMap { account in
            account.routeType.map { (account.id, [$0]) }
        })
        do {
            let accounts = allocationValidationAccounts
            let result = try SurplusAllocationCalculator.calculate(plan: plan, reserves: metadata.reserves,
                accounts: accounts, productLabels: labels, preferences: metadata.preferences,
                salaryReceipt: payslipReceiptState)
            try SurplusAllocationCalculator.validatePublication(result, plan: plan, accounts: accounts,
                preferences: metadata.preferences)
            return .success(result)
        } catch let error as SurplusAllocationError { return .failure(error) }
        catch { return .failure(.invalidRecord) }
    }
    var allocationPublicationIssue: SurplusAllocationError? {
        if case .failure(let error) = allocationResult { return error }
        return nil
    }
    var allocationReviewMessage: String? {
        if saveState == .retentionFailed { return errorMessage ?? "Could not retain the latest entries. Keep this window open and reopen the database." }
        if saveState == .failed { return errorMessage ?? "Could not publish these instructions. The previously saved plan remains unchanged." }
        guard let issue = allocationPublicationIssue else { return nil }
        if !hasValidCalculation { return "Complete the marked entries. Incomplete text is retained and has not been approved in the saved plan." }
        let preservation = allocationCanonicalPlan?.assistance?.surplusAllocation != nil
            ? " Your worksheet changes are retained. Previously approved amounts remain unchanged in the saved plan."
            : " Your entries are retained until the allocation is complete and valid."
        if !FundingPlanCalculator.staleReviewedObligationIDs(in: plan).isEmpty {
            return "A linked card-payment review belongs to a different salary cycle. Review the remaining payment in Forecast & reviews; the upcoming estimate is preserved." + preservation
        }
        return (issue.errorDescription ?? "Review the monthly allocation.") + preservation
    }

    var allocationRows: [AllocationEditorRow] {
        var rows = [AllocationEditorRow(id: .retention, kind: "Cash retention", date: nil,
            sourceAccountID: allocationMetadata?.preferences?.retentionAccountID, destination: "Keep in CBQ",
            amount: plan.keepInCBQ.flatMap { try? PlanningAmount($0) }, received: nil, purpose: "Current-account retention")]
        let assistance = plan.assistance
        rows += (assistance?.contributions ?? []).map { contribution in
            let reserve = allocationReserves.first { $0.id == contribution.designationID }
            return .init(id: .contribution(contribution.id), kind: reserve?.kind == .planningDeposit ? "Planned reserve deposit" : "Cash earmark",
                date: contribution.dueDate, sourceAccountID: contribution.fundingAccountID,
                destination: reserve?.title ?? "Saved reserve unavailable", amount: contribution.amount,
                received: nil, purpose: "Reserve contribution")
        }
        rows += (assistance?.transfers ?? []).map { transfer in
            .init(id: .transfer(transfer.id), kind: "Own-account transfer", date: transfer.date,
                sourceAccountID: transfer.fromAccountID, destination: allocationAccountTitle(transfer.toAccountID),
                amount: transfer.sent, received: transfer.received,
                purpose: assistance?.surplusAllocation?.requiredIndiaTransferID == transfer.id ? "India obligations and surplus" : "Own-account funding")
        }
        rows += (assistance?.surplusAllocation?.investments ?? []).map { investment in
            let kind: String, title: String
            switch investment.instrument {
            case .ibkr(_, let name, _): kind = "IBKR security"; title = name
            case .indianMutualFund(_, let name): kind = "Indian mutual fund"; title = name
            }
            return .init(id: .investment(investment.id), kind: kind, date: investment.date,
                sourceAccountID: investment.fundingAccountID, destination: title.isEmpty ? "Choose exact instrument" : title,
                amount: investment.amount, received: nil, purpose: "Investment intention")
        }
        return rows
    }

    func allocationAccountTitle(_ id: String) -> String {
        allocationSourceContext.accounts.first { $0.id == id }?.title ?? (id.isEmpty ? "Choose account" : "Saved account unavailable")
    }
    func allocationAccountQualification(_ id: String) -> String? {
        let account = allocationSourceContext.accounts.first { $0.id == id }
        var details: [String] = []
        if account?.routeType == "NRO" { details.append("Protected emergency cash · an explicit source choice is required for this plan") }
        if allocationValidationAccounts.first(where: { $0.id == id })?.institutionId == "HDFC Bank" {
            details.append("Bank minimum balance is not modelled; eligible funding needs review")
        }
        return details.isEmpty ? nil : details.joined(separator: ". ")
    }
    func eligibleAllocationDestinations(from sourceID: String) -> [IntelligenceAccountContext] {
        guard let source = allocationAccounts.first(where: { $0.id == sourceID }) else { return [] }
        return allocationAccounts.filter { PlanningIntelligence.permitsPlanningRoute(from: source, to: $0,
            retentionAccountID: allocationMetadata?.preferences?.retentionAccountID) }
    }
    func eligibleAllocationSources(for row: AllocationRowID) -> [IntelligenceAccountContext] {
        let nativeSources = allocationAccounts.filter {
            $0.currency == "INR" || $0.id == allocationMetadata?.preferences?.retentionAccountID
        }
        switch row {
        case .retention: return nativeSources.filter { $0.id == allocationMetadata?.preferences?.retentionAccountID }
        case .contribution(let id):
            guard let reserve = allocationReserves.first(where: { $0.id == id }) else { return [] }
            return nativeSources.filter {
                $0.currency == reserve.target.currency && (reserve.kind == .planningDeposit || $0.id == reserve.accountID)
            }
        case .transfer:
            return nativeSources.filter { !eligibleAllocationDestinations(from: $0.id).isEmpty }
        case .investment(let id):
            if case .indianMutualFund = plan.assistance?.surplusAllocation?.investments.first(where: { $0.id == id })?.instrument {
                return nativeSources.filter { $0.currency == "INR" }
            }
            return nativeSources
        }
    }
    func eligibleAllocationFundingTransfers(for row: AllocationRowID) -> [PlanTransfer] {
        guard let entry = allocationRows.first(where: { $0.id == row }), let source = entry.sourceAccountID else { return [] }
        let transfers = plan.assistance?.transfers ?? []
        return transfers.filter { transfer in
            guard transfer.toAccountID == source, row != .transfer(transfer.id),
                  entry.date.map({ transfer.date <= $0 }) ?? true else { return false }
            var ancestor = transfer.fundingTransferID, seen: Set<String> = []
            while let id = ancestor {
                guard seen.insert(id).inserted, row != .transfer(id) else { return false }
                ancestor = transfers.first { $0.id == id }?.fundingTransferID
            }
            return true
        }
    }

    func allocationStatus(for row: AllocationRowID) -> AllocationPlanningStatus {
        let hasError = fieldErrors.keys.contains { $0.hasPrefix(row.fieldPrefix) } || (row == .retention && fieldErrors[MoneyField.reserve.rawValue] != nil)
        if [.canonicalChanged, .providerChanged, .committedToPreviousProvider, .committedNeedsRefresh].contains(saveState) { return .needsReview }
        let approved = !hasError && allocationCanonicalPlan?.assistance?.surplusAllocation != nil && allocationMatchesCanonical(row)
        if [.failed, .retentionFailed].contains(saveState) { return approved ? .approvedInPlan : .couldNotSave }
        if hasError { return .incompleteEntry }
        // An unfinished field elsewhere cannot revoke an unchanged instruction
        // already in the saved plan. A complete but unaffordable revision below
        // still requires capacity review without changing its approved amount.
        if approved && !hasValidCalculation { return .approvedInPlan }
        if allocationPublicationIssue != nil { return .needsReview }
        if approved { return .approvedInPlan }
        if plan.assistance?.surplusAllocation == nil { return .existingChoice }
        if allocationCanonicalPlan?.assistance?.surplusAllocation == nil && allocationMatchesCanonical(row) { return .existingChoice }
        return .pending
    }
    func allocationEvidenceStatus(for row: AllocationRowID) -> String {
        if case .transfer(let id) = row, let transfer = plan.assistance?.transfers?.first(where: { $0.id == id }) {
            if !(transfer.transactionIDs?.isEmpty ?? true) { return "Needs review" }
            if plan.balances.filter({ $0.included && [transfer.fromAccountID, transfer.toAccountID].contains($0.accountID) })
                .contains(where: { $0.financialBalanceDate.map { $0.canonical >= transfer.date } ?? false }) { return "Needs review" }
        }
        return "Not yet observed"
    }
    private func allocationMatchesCanonical(_ row: AllocationRowID) -> Bool {
        guard let canonical = allocationCanonicalPlan else { return false }
        switch row {
        case .retention: return plan.keepInCBQ == canonical.keepInCBQ
        case .contribution(let id):
            guard let current = plan.assistance?.contributions.first(where: { $0.id == id }) else { return false }
            return current == canonical.assistance?.contributions.first(where: { $0.id == id })
                && (plan.assistance?.surplusAllocation?.keepInCBQDesignationID == id) == (canonical.assistance?.surplusAllocation?.keepInCBQDesignationID == id)
        case .transfer(let id):
            guard let current = plan.assistance?.transfers?.first(where: { $0.id == id }) else { return false }
            return current == canonical.assistance?.transfers?.first(where: { $0.id == id })
                && (plan.assistance?.surplusAllocation?.requiredIndiaTransferID == id) == (canonical.assistance?.surplusAllocation?.requiredIndiaTransferID == id)
        case .investment(let id):
            guard let current = plan.assistance?.surplusAllocation?.investments.first(where: { $0.id == id }) else { return false }
            return current == canonical.assistance?.surplusAllocation?.investments.first(where: { $0.id == id })
        }
    }

    func allocationText(_ field: AllocationEditorField, row: AllocationRowID) -> String {
        if row == .retention && field == .amount { return moneyText(.reserve) }
        if let raw = rawText[row.fieldKey(field)] { return raw }
        func number(_ value: PlanningAmount?) -> String {
            (value?.decimal ?? "").replacingOccurrences(of: ".", with: allocationInputLocale.decimalSeparator ?? ".")
        }
        switch row {
        case .retention: return ""
        case .contribution(let id):
            guard let value = plan.assistance?.contributions.first(where: { $0.id == id }) else { return "" }
            switch field {
            case .amount: return number(value.amount)
            case .date: return value.dueDate
            default: return ""
            }
        case .transfer(let id):
            guard let value = plan.assistance?.transfers?.first(where: { $0.id == id }) else { return "" }
            switch field {
            case .amount: return number(value.sent)
            case .received: return number(value.received)
            case .date: return value.date
            case .requiredIndiaFunding: return number(value.requiredIndiaFunding)
            default: return ""
            }
        case .investment(let id):
            guard let value = plan.assistance?.surplusAllocation?.investments.first(where: { $0.id == id }) else { return "" }
            switch field {
            case .amount: return number(value.amount)
            case .date: return value.date
            case .instrumentID:
                switch value.instrument { case .ibkr(let code, _, _), .indianMutualFund(let code, _): return code }
            case .instrumentTitle:
                switch value.instrument { case .ibkr(_, let title, _), .indianMutualFund(_, let title): return title }
            case .quoteCurrency:
                if case .ibkr(_, _, let currency) = value.instrument { return currency }; return "INR"
            default: return ""
            }
        }
    }
    func allocationError(_ field: AllocationEditorField, row: AllocationRowID) -> String? {
        row == .retention && field == .amount ? fieldErrors[MoneyField.reserve.rawValue] : fieldErrors[row.fieldKey(field)]
    }

    @discardableResult
    func addAllocationContribution(designationID: String) -> AllocationRowID? {
        guard canEdit, plan.calculationVersion == .budgetV1,
              let reserve = allocationReserves.first(where: { $0.id == designationID }),
              plan.assistance?.contributions.contains(where: { $0.id == designationID }) != true else { return nil }
        let row = AllocationRowID.contribution(designationID), date = plan.recurringStart.canonical
        editAllocation { plan, raw, errors in
            plan.assistance?.contributions.append(.init(designationID: designationID, fundingAccountID: "",
                amount: .init(currency: reserve.target.currency, decimal: "0.00"), dueDate: date))
            raw[row.fieldKey(.amount)] = ""; errors[row.fieldKey(.amount)] = "Enter the planned contribution"
            errors[row.fieldKey(.fundingAccount)] = "Choose the exact funding account"
        }
        return row
    }
    @discardableResult
    func addAllocationTransfer() -> AllocationRowID? {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return nil }
        let id = UUID().uuidString, date = plan.recurringStart.canonical, row = AllocationRowID.transfer(id)
        editAllocation { plan, raw, errors in
            if plan.assistance?.transfers == nil { plan.assistance?.transfers = [] }
            plan.assistance?.transfers?.append(.init(id: id, fromAccountID: "", toAccountID: "",
                sent: .init(currency: "QAR", decimal: "0.00"), received: .init(currency: "INR", decimal: "0.00"),
                date: date, conversionBasis: ""))
            raw[row.fieldKey(.received)] = ""; errors[row.fieldKey(.received)] = "Enter the expected receipt"
            errors[row.fieldKey(.fundingAccount)] = "Choose the exact source account"
            errors[row.fieldKey(.destinationAccount)] = "Choose an eligible destination"
        }
        return row
    }
    @discardableResult
    func addAllocationInvestment(kind: AllocationInvestmentKind) -> AllocationRowID? {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return nil }
        let id = UUID().uuidString, row = AllocationRowID.investment(id), date = plan.recurringStart.canonical
        editAllocation { plan, raw, errors in
            let instrument: PlannedInvestmentInstrument = kind == .ibkr
                ? .ibkr(conid: "", title: "", quoteCurrency: "") : .indianMutualFund(schemeCode: "", title: "")
            plan.assistance?.surplusAllocation?.investments.append(.init(id: id, instrument: instrument,
                fundingAccountID: "", amount: .init(currency: kind == .ibkr ? "QAR" : "INR", decimal: "0.00"), date: date))
            for field in [AllocationEditorField.amount, .instrumentID, .instrumentTitle] { raw[row.fieldKey(field)] = "" }
            errors[row.fieldKey(.amount)] = "Enter the native funding amount"
            errors[row.fieldKey(.fundingAccount)] = "Choose the exact funding account"
            errors[row.fieldKey(.instrumentID)] = "Enter the exact numeric instrument identity"
            errors[row.fieldKey(.instrumentTitle)] = "Enter the selected instrument's name"
            if kind == .ibkr { errors[row.fieldKey(.quoteCurrency)] = "Enter the instrument's quote currency" }
        }
        return row
    }

    func removeAllocation(_ row: AllocationRowID) {
        guard row != .retention, allocationRows.contains(where: { $0.id == row }) else { return }
        editAllocation { plan, raw, errors in
            switch row {
            case .retention: break
            case .contribution(let id):
                plan.assistance?.contributions.removeAll { $0.id == id }
                if plan.assistance?.surplusAllocation?.keepInCBQDesignationID == id { plan.assistance?.surplusAllocation?.keepInCBQDesignationID = nil }
            case .transfer(let id):
                plan.assistance?.transfers?.removeAll { $0.id == id }
                if plan.assistance?.surplusAllocation?.requiredIndiaTransferID == id { plan.assistance?.surplusAllocation?.requiredIndiaTransferID = nil }
                // Dependent intentions retain their exact link and require review.
            case .investment(let id): plan.assistance?.surplusAllocation?.investments.removeAll { $0.id == id }
            }
            for key in Array(raw.keys) where key.hasPrefix(row.fieldPrefix) { raw[key] = nil }
            for key in Array(errors.keys) where key.hasPrefix(row.fieldPrefix) { errors[key] = nil }
        }
    }

    func setAllocationText(_ field: AllocationEditorField, row: AllocationRowID, text: String) {
        if row == .retention && field == .amount {
            guard canEdit, plan.calculationVersion == .budgetV1 else { return }
            editAllocation { _, _, _ in }
            _ = updateMoney(.reserve, text: text)
            return
        }
        guard allocationRows.contains(where: { $0.id == row }) else { return }
        let inputLocale = allocationInputLocale
        editAllocation { plan, raw, errors in
            let key = row.fieldKey(field)
            raw[key] = text
            func amount(_ currency: String) -> PlanningAmount? {
                guard let money = try? PlannerInputCodec.money(text, currency: currency, locale: inputLocale), money.amount >= 0,
                      let value = try? PlanningAmount(money) else { errors[key] = "Enter a complete nonnegative \(currency) amount"; return nil }
                errors[key] = nil; return value
            }
            func date() -> String? {
                guard (try? StatementDate(canonical: text)) != nil else { errors[key] = "Enter a valid date as YYYY-MM-DD"; return nil }
                errors[key] = nil; return text
            }
            switch row {
            case .retention: break
            case .contribution(let id):
                guard let index = plan.assistance?.contributions.firstIndex(where: { $0.id == id }) else { return }
                if field == .amount, let value = amount(plan.assistance!.contributions[index].amount.currency) { plan.assistance?.contributions[index].amount = value }
                if field == .date, let value = date() { plan.assistance?.contributions[index].dueDate = value }
            case .transfer(let id):
                guard let index = plan.assistance?.transfers?.firstIndex(where: { $0.id == id }), var transfer = plan.assistance?.transfers?[index] else { return }
                if field == .received, let value = amount(transfer.received.currency) {
                    transfer.received = value
                    Self.recalculateTransferPrincipal(&transfer, plan: plan, row: row, errors: &errors)
                }
                if field == .date, let value = date() { transfer.date = value }
                if field == .requiredIndiaFunding {
                    if text.isEmpty { transfer.requiredIndiaFunding = nil; errors[key] = nil }
                    else if let value = amount("INR") { transfer.requiredIndiaFunding = value }
                }
                plan.assistance?.transfers?[index] = transfer
            case .investment(let id):
                guard let index = plan.assistance?.surplusAllocation?.investments.firstIndex(where: { $0.id == id }), var value = plan.assistance?.surplusAllocation?.investments[index] else { return }
                if field == .amount, let parsed = amount(value.amount.currency) { value.amount = parsed }
                if field == .date, let parsed = date() { value.date = parsed }
                if [.instrumentID, .instrumentTitle, .quoteCurrency].contains(field) {
                    let valid: Bool
                    switch field {
                    case .instrumentID: valid = !text.isEmpty && text.utf8.allSatisfy { (48...57).contains($0) } && text.utf8.contains { $0 != 48 }
                    case .instrumentTitle: valid = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 240
                    case .quoteCurrency: valid = (try? CurrencyCode(text))?.code == text
                    default: valid = false
                    }
                    errors[key] = valid ? nil : (field == .instrumentID ? "Enter the exact numeric instrument identity" : field == .quoteCurrency ? "Enter a valid uppercase currency code" : "Enter the selected instrument's name")
                    if valid {
                        switch value.instrument {
                        case let .ibkr(code, title, currency): value.instrument = .ibkr(conid: field == .instrumentID ? text : code, title: field == .instrumentTitle ? text : title, quoteCurrency: field == .quoteCurrency ? text : currency)
                        case let .indianMutualFund(code, title): value.instrument = .indianMutualFund(schemeCode: field == .instrumentID ? text : code, title: field == .instrumentTitle ? text : title)
                        }
                    }
                }
                plan.assistance?.surplusAllocation?.investments[index] = value
            }
        }
    }

    func setAllocationFundingAccount(_ accountID: String, row: AllocationRowID) {
        guard row != .retention, let account = eligibleAllocationSources(for: row).first(where: { $0.id == accountID }) else { return }
        if case .contribution(let id) = row, allocationReserves.first(where: { $0.id == id })?.target.currency != account.currency { return }
        if case .investment(let id) = row,
           case .indianMutualFund = plan.assistance?.surplusAllocation?.investments.first(where: { $0.id == id })?.instrument,
           account.currency != "INR" { return }
        editAllocation { plan, raw, errors in
            switch row {
            case .retention: return
            case .contribution(let id):
                guard let index = plan.assistance?.contributions.firstIndex(where: { $0.id == id }) else { return }
                plan.assistance?.contributions[index].fundingAccountID = accountID
            case .transfer(let id):
                guard let index = plan.assistance?.transfers?.firstIndex(where: { $0.id == id }), var transfer = plan.assistance?.transfers?[index] else { return }
                transfer.fromAccountID = accountID
                transfer.sent.currency = account.currency
                Self.recalculateTransferPrincipal(&transfer, plan: plan, row: row, errors: &errors)
                plan.assistance?.transfers?[index] = transfer
            case .investment(let id):
                guard let index = plan.assistance?.surplusAllocation?.investments.firstIndex(where: { $0.id == id }) else { return }
                plan.assistance?.surplusAllocation?.investments[index].fundingAccountID = accountID
                if plan.assistance?.surplusAllocation?.investments[index].amount.currency != account.currency {
                    plan.assistance?.surplusAllocation?.investments[index].amount = .init(currency: account.currency, decimal: "0.00")
                    raw[row.fieldKey(.amount)] = ""; errors[row.fieldKey(.amount)] = "Enter the funding amount in \(account.currency)"
                }
            }
            errors[row.fieldKey(.fundingAccount)] = nil
        }
    }
    func setAllocationDestinationAccount(_ accountID: String, row: AllocationRowID) {
        guard case .transfer(let id) = row, let transfer = plan.assistance?.transfers?.first(where: { $0.id == id }),
              let destination = eligibleAllocationDestinations(from: transfer.fromAccountID).first(where: { $0.id == accountID }) else { return }
        editAllocation { plan, raw, errors in
            guard let index = plan.assistance?.transfers?.firstIndex(where: { $0.id == id }), var value = plan.assistance?.transfers?[index] else { return }
            value.toAccountID = accountID
            if value.received.currency != destination.currency {
                value.received = .init(currency: destination.currency, decimal: "0.00")
                raw[row.fieldKey(.received)] = ""; errors[row.fieldKey(.received)] = "Enter the receipt in \(destination.currency)"
            }
            Self.recalculateTransferPrincipal(&value, plan: plan, row: row, errors: &errors)
            plan.assistance?.transfers?[index] = value
            errors[row.fieldKey(.destinationAccount)] = nil
        }
    }
    func setAllocationFundingTransfer(_ id: String?, row: AllocationRowID) {
        guard row != .retention, allocationRows.contains(where: { $0.id == row }),
              id == nil || eligibleAllocationFundingTransfers(for: row).contains(where: { $0.id == id }) else { return }
        editAllocation { plan, _, errors in
            switch row {
            case .retention: return
            case .contribution(let idOfRow):
                if let index = plan.assistance?.contributions.firstIndex(where: { $0.id == idOfRow }) { plan.assistance?.contributions[index].fundingTransferID = id }
            case .transfer(let idOfRow):
                if let index = plan.assistance?.transfers?.firstIndex(where: { $0.id == idOfRow }) { plan.assistance?.transfers?[index].fundingTransferID = id }
            case .investment(let idOfRow):
                if let index = plan.assistance?.surplusAllocation?.investments.firstIndex(where: { $0.id == idOfRow }) { plan.assistance?.surplusAllocation?.investments[index].fundingTransferID = id }
            }
            errors[row.fieldKey(.fundingTransfer)] = nil
        }
    }
    func setAllocationIncludesRequiredIndia(_ include: Bool, transferID: String) {
        guard let transfer = plan.assistance?.transfers?.first(where: { $0.id == transferID }), transfer.sent.currency == "QAR", transfer.received.currency == "INR" else { return }
        guard include || plan.assistance?.surplusAllocation?.requiredIndiaTransferID == transferID else { return }
        editAllocation { plan, _, _ in
            plan.assistance?.surplusAllocation?.requiredIndiaTransferID = include ? transferID : nil
        }
    }
    func setAllocationIncludesRetention(_ include: Bool, designationID: String) {
        guard let reserve = allocationReserves.first(where: { $0.id == designationID }), reserve.kind == .accountCash,
              reserve.accountID == allocationMetadata?.preferences?.retentionAccountID,
              let contribution = plan.assistance?.contributions.first(where: { $0.id == designationID }),
              contribution.fundingAccountID == reserve.accountID, contribution.fundingTransferID == nil else { return }
        guard include || plan.assistance?.surplusAllocation?.keepInCBQDesignationID == designationID else { return }
        editAllocation { plan, _, _ in
            plan.assistance?.surplusAllocation?.keepInCBQDesignationID = include ? designationID : nil
        }
    }
    private static func recalculateTransferPrincipal(_ transfer: inout PlanTransfer, plan: FundingPlan,
                                                       row: AllocationRowID, errors: inout [String: String]) {
        guard let received = try? transfer.received.money(),
              let sent = FundingPlanCalculator.transferPrincipal(received: received, fromCurrency: transfer.sent.currency, plan: plan),
              let amount = try? PlanningAmount(sent) else {
            errors[row.fieldKey(.amount)] = "Complete the monthly planning FX to calculate the principal"; return
        }
        transfer.sent = amount
        transfer.conversionBasis = transfer.sent.currency == transfer.received.currency ? "Same-currency own-account transfer"
            : plan.referenceMode == .manual ? "Month-local manual rate" : "Month-local Al Dar reference"
        errors[row.fieldKey(.amount)] = nil
    }
}
