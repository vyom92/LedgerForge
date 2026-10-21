import Foundation

/// The bounded, durable part of a successful planning-write result. Current
/// canonical readback is added after commit and is deliberately not stored here.
@MainActor
enum PlanningWriteReceiptContent {
    static func make(request: PlanningChangeRequest, before: FundingPlan, after: FundingPlan) throws -> [String: Any] {
        guard before.id == request.planID, after.id == request.planID,
              before.workspaceID == request.workspaceID, after.workspaceID == request.workspaceID,
              before.month == request.month, after.month == request.month else {
            throw PlanningChangeError.invalid("receipt.plan_identity")
        }
        var changes: [[String: Any]] = []
        var derived: [[String: Any]] = []
        var createdIDs: [String] = []
        var removedIDs: [String] = []

        func append(_ type: String, identity: [String: Any], field: String?, old: Any?, new: Any,
                    to output: inout [[String: Any]], reason: String? = nil) throws {
            guard try !equal(old, new) else { return }
            var target = identity
            target["type"] = type
            if let field { target["field"] = field }
            var item: [String: Any] = ["target": target, "after": new]
            // Retain only this changed field's prior canonical value. A newly
            // created field has no prior value; removal keeps identity only.
            if let old { item["before"] = old }
            if let reason { item["reason"] = reason }
            output.append(item)
        }
        func changed(_ type: String, _ identity: [String: Any], _ field: String,
                     _ old: Any?, _ new: Any) throws {
            try append(type, identity: identity, field: field, old: old, new: new, to: &changes)
        }
        func effect(_ type: String, _ identity: [String: Any], _ field: String,
                    _ old: Any?, _ new: Any, _ reason: String) throws {
            try append(type, identity: identity, field: field, old: old, new: new, to: &derived, reason: reason)
        }

        for change in request.changes {
            switch change {
            case let .monthlyAmount(field, _):
                let old = try monthlyAmount(before, field), new = try monthlyAmount(after, field)
                try changed("monthly_amount", [:], field.rawValue, old, new)
                if field == .expectedFixed || field == .expectedVariable || field == .configuredTransferFee {
                    let oldOrigin = provenance(before, field), newOrigin = provenance(after, field)
                    try effect("monthly_amount", ["monthly_field": field.rawValue], "provenance", oldOrigin, newOrigin, "owner_entered_amount")
                }
            case let .deductionAmount(id, _):
                let old = try required(before.deductions.first { $0.id == id }, "receipt.deduction.before")
                let new = try required(after.deductions.first { $0.id == id }, "receipt.deduction.after")
                try changed("deduction_amount", ["deduction_id": id], "amount", try money(old.money), try money(new.money))
            case let .obligation(region, id, fields):
                let old = try required(obligations(before, region).first { $0.id == id }, "receipt.obligation.before")
                let new = try required(obligations(after, region).first { $0.id == id }, "receipt.obligation.after")
                let identity: [String: Any] = ["region": region.rawValue, "obligation_id": id]
                if fields.amount.isSupplied { try changed("obligation", identity, "amount", try money(old.money), try money(new.money)) }
                if fields.dueDate.isSupplied {
                    try changed("obligation", identity, "due_date", nullable(old.dueDate?.canonical), nullable(new.dueDate?.canonical))
                    try effect("obligation", identity, "carried_date_override",
                               nullable(before.assistance?.carriedBillDates?[id]), nullable(after.assistance?.carriedBillDates?[id]),
                               "explicit_due_date")
                }
                if fields.included.isSupplied { try changed("obligation", identity, "included", old.included, new.included) }
                if fields.payingAccountID.isSupplied {
                    try changed("obligation", identity, "paying_account_id",
                                nullable(before.assistance?.billFundingAccounts?[id]), nullable(after.assistance?.billFundingAccounts?[id]))
                }
            case let .planningBalance(id, accountID, fields):
                let old = try required(before.balances.first { $0.id == id && $0.accountID == accountID }, "receipt.balance.before")
                let new = try required(after.balances.first { $0.id == id && $0.accountID == accountID }, "receipt.balance.after")
                let identity: [String: Any] = ["balance_id": id, "account_id": accountID]
                if fields.amount.isSupplied {
                    try changed("planning_balance", identity, "amount", try optionalMoney(old.money), try optionalMoney(new.money))
                    try effect("planning_balance", identity, "provenance", old.provenance.persistenceCode,
                               new.provenance.persistenceCode, "owner_entered_estimate")
                    try effect("planning_balance", identity, "financial_balance_date",
                               nullable(old.financialBalanceDate?.canonical), nullable(new.financialBalanceDate?.canonical),
                               "owner_entered_estimate")
                }
                if fields.included.isSupplied { try changed("planning_balance", identity, "included", old.included, new.included) }
            case .manualFX:
                let identity: [String: Any] = [:]
                try changed("manual_fx", identity, "inr_per_qar", nullable(rate(before.planningFX)), nullable(rate(after.planningFX)))
                try changed("manual_fx", identity, "observation_date", nullable(before.planningFX?.observationDate.canonical),
                            nullable(after.planningFX?.observationDate.canonical))
                try effect("manual_fx", identity, "reference_mode", before.referenceMode.rawValue, after.referenceMode.rawValue,
                           "manual_fx_selected")
                try effect("manual_fx", identity, "effective_external_reference",
                           before.effectiveAlDarReference == nil ? NSNull() : "present",
                           after.effectiveAlDarReference == nil ? NSNull() : "present", "manual_fx_selected")
            case let .contribution(action, id, fields):
                let old = before.assistance?.contributions.first { $0.id == id }
                let new = try required(after.assistance?.contributions.first { $0.id == id }, "receipt.contribution.after")
                let identity: [String: Any] = ["designation_id": id]
                if action == .create { createdIDs.append(id) }
                if fields.amount.isSupplied { try changed("contribution", identity, "amount", try old.map { try planningMoney($0.amount) }, try planningMoney(new.amount)) }
                if fields.date.isSupplied { try changed("contribution", identity, "date", old?.dueDate, new.dueDate) }
                if fields.fundingAccountID.isSupplied { try changed("contribution", identity, "funding_account_id", old?.fundingAccountID, new.fundingAccountID) }
                if fields.fundingTransferID.isSupplied { try changed("contribution", identity, "funding_transfer_id", old.map { nullable($0.fundingTransferID) }, nullable(new.fundingTransferID)) }
            case let .transfer(action, id, fields):
                let old = before.assistance?.transfers?.first { $0.id == id }
                let new = try required(after.assistance?.transfers?.first { $0.id == id }, "receipt.transfer.after")
                let identity: [String: Any] = ["transfer_id": id]
                if action == .create { createdIDs.append(id) }
                if fields.fromAccountID.isSupplied { try changed("transfer", identity, "from_account_id", old?.fromAccountID, new.fromAccountID) }
                if fields.toAccountID.isSupplied { try changed("transfer", identity, "to_account_id", old?.toAccountID, new.toAccountID) }
                if fields.received.isSupplied { try changed("transfer", identity, "received", try old.map { try planningMoney($0.received) }, try planningMoney(new.received)) }
                if fields.date.isSupplied { try changed("transfer", identity, "date", old?.date, new.date) }
                if fields.fundingTransferID.isSupplied { try changed("transfer", identity, "funding_transfer_id", old.map { nullable($0.fundingTransferID) }, nullable(new.fundingTransferID)) }
                if fields.requiredIndiaFunding.isSupplied {
                    try changed("transfer", identity, "required_india_funding", try old.map { try optionalPlanningMoney($0.requiredIndiaFunding) },
                                try optionalPlanningMoney(new.requiredIndiaFunding))
                }
            case let .investment(action, id, fields):
                let old = before.assistance?.surplusAllocation?.investments.first { $0.id == id }
                let new = try required(after.assistance?.surplusAllocation?.investments.first { $0.id == id }, "receipt.investment.after")
                let identity: [String: Any] = ["investment_id": id]
                if action == .create { createdIDs.append(id) }
                if fields.instrument.isSupplied { try changed("investment", identity, "instrument", old.map { instrument($0.instrument) }, instrument(new.instrument)) }
                if fields.fundingAccountID.isSupplied { try changed("investment", identity, "funding_account_id", old?.fundingAccountID, new.fundingAccountID) }
                if fields.amount.isSupplied { try changed("investment", identity, "amount", try old.map { try planningMoney($0.amount) }, try planningMoney(new.amount)) }
                if fields.date.isSupplied { try changed("investment", identity, "date", old?.date, new.date) }
                if fields.fundingTransferID.isSupplied { try changed("investment", identity, "funding_transfer_id", old.map { nullable($0.fundingTransferID) }, nullable(new.fundingTransferID)) }
            case let .allocationLinks(fields):
                let identity: [String: Any] = [:]
                if fields.requiredIndiaTransferID.isSupplied {
                    try changed("allocation_links", identity, "required_india_transfer_id",
                                nullable(before.assistance?.surplusAllocation?.requiredIndiaTransferID),
                                nullable(after.assistance?.surplusAllocation?.requiredIndiaTransferID))
                }
                if fields.keepInCBQDesignationID.isSupplied {
                    try changed("allocation_links", identity, "keep_in_cbq_designation_id",
                                nullable(before.assistance?.surplusAllocation?.keepInCBQDesignationID),
                                nullable(after.assistance?.surplusAllocation?.keepInCBQDesignationID))
                }
            case let .removeAllocation(kind, id):
                let existed: Bool = switch kind {
                case .contribution: before.assistance?.contributions.contains { $0.id == id } == true
                case .transfer: before.assistance?.transfers?.contains { $0.id == id } == true
                case .investment: before.assistance?.surplusAllocation?.investments.contains { $0.id == id } == true
                }
                guard existed else { throw PlanningChangeError.invalid("receipt.removal.before") }
                removedIDs.append(id)
                try changed("remove_allocation", ["kind": kind.rawValue, "record_id": id], "record", nil, NSNull())
            }
        }

        // These values arise from existing planner rules, not from caller-supplied fields.
        let oldTransfers = Dictionary(uniqueKeysWithValues: (before.assistance?.transfers ?? []).map { ($0.id, $0) })
        for transfer in after.assistance?.transfers ?? [] {
            let identity: [String: Any] = ["transfer_id": transfer.id]
            try effect("transfer", identity, "sent", try oldTransfers[transfer.id].map { try planningMoney($0.sent) },
                       try planningMoney(transfer.sent), "derived_principal")
            try effect("transfer", identity, "conversion_basis", oldTransfers[transfer.id]?.conversionBasis,
                       transfer.conversionBasis, "derived_principal")
        }
        try effect("allocation", [:], "envelope_id", nullable(before.assistance?.surplusAllocation?.id),
                   nullable(after.assistance?.surplusAllocation?.id), "explicit_allocation_edit")
        let explicitRoot = request.changes.contains { change in
            if case .allocationLinks(let fields) = change { return fields.requiredIndiaTransferID.isSupplied }
            return false
        }
        let explicitKeep = request.changes.contains { change in
            if case .allocationLinks(let fields) = change { return fields.keepInCBQDesignationID.isSupplied }
            return false
        }
        if !explicitRoot {
            try effect("allocation_links", [:], "required_india_transfer_id",
                       nullable(before.assistance?.surplusAllocation?.requiredIndiaTransferID),
                       nullable(after.assistance?.surplusAllocation?.requiredIndiaTransferID), "allocation_root_change")
        }
        if !explicitKeep {
            try effect("allocation_links", [:], "keep_in_cbq_designation_id",
                       nullable(before.assistance?.surplusAllocation?.keepInCBQDesignationID),
                       nullable(after.assistance?.surplusAllocation?.keepInCBQDesignationID), "keep_overlap_change")
        }

        // A removed row is already identified by the request and ID list. The
        // receipt excludes deleted row content and all unrelated plan content.
        let touchedAllocations = request.changes.contains { change in
            switch change {
            case .contribution, .transfer, .investment, .allocationLinks, .removeAllocation: true
            default: false
            }
        }
        let limitations = touchedAllocations
            ? ["Planning amounts do not establish verified available cash.",
               "Planned transfers and investments do not execute transactions or orders."]
            : ["Planning amounts do not establish verified available cash."]
        let result: [String: Any] = [
            "changes": changes, "created_record_ids": createdIDs, "removed_record_ids": removedIDs,
            "derived_changes": derived, "limitations": limitations
        ]
        let encoded = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .withoutEscapingSlashes])
        guard encoded.count <= 65_536 else { throw PlanningChangeError.invalid("receipt.size") }
        return result
    }

    private static func equal(_ lhs: Any?, _ rhs: Any) throws -> Bool {
        guard let lhs else { return false }
        let a = try JSONSerialization.data(withJSONObject: ["v": lhs], options: [.sortedKeys, .withoutEscapingSlashes])
        let b = try JSONSerialization.data(withJSONObject: ["v": rhs], options: [.sortedKeys, .withoutEscapingSlashes])
        return a == b
    }

    private static func required<T>(_ value: T?, _ path: String) throws -> T {
        guard let value else { throw PlanningChangeError.invalid(path) }
        return value
    }

    private static func nullable(_ value: String?) -> Any { value ?? NSNull() as Any }
    private static func money(_ value: Money) throws -> [String: Any] {
        ["currency": value.currency.code, "decimal": try value.canonicalDecimalString()]
    }
    private static func optionalMoney(_ value: Money?) throws -> Any {
        if let value { return try money(value) }
        return NSNull()
    }
    private static func planningMoney(_ value: PlanningAmount) throws -> [String: Any] {
        try money(value.money())
    }
    private static func optionalPlanningMoney(_ value: PlanningAmount?) throws -> Any {
        if let value { return try planningMoney(value) }
        return NSNull()
    }
    private static func rate(_ value: FundingPlanFX?) -> String? {
        value.map { NSDecimalNumber(decimal: $0.inrPerQAR).stringValue }
    }
    private static func obligations(_ plan: FundingPlan, _ region: PlanningRegion) -> [FundingPlanCommitment] {
        region == .qatar ? plan.qatarCommitments : plan.indiaCommitments
    }
    private static func monthlyAmount(_ plan: FundingPlan, _ field: PlanningMonthlyField) throws -> Any {
        switch field {
        case .expectedFixed: try money(plan.expectedFixedEarnings)
        case .expectedVariable: try money(plan.expectedVariableEarnings)
        case .configuredTransferFee: try money(plan.configuredTransferFee)
        case .keepInCBQ: try optionalMoney(plan.keepInCBQ)
        }
    }
    private static func provenance(_ plan: FundingPlan, _ field: PlanningMonthlyField) -> String {
        switch field {
        case .expectedFixed: plan.expectedFixedProvenance.persistenceCode
        case .expectedVariable: plan.expectedVariableProvenance.persistenceCode
        case .configuredTransferFee: plan.configuredTransferFeeProvenance.persistenceCode
        case .keepInCBQ: "manual"
        }
    }
    private static func instrument(_ value: PlannedInvestmentInstrument) -> [String: Any] {
        switch value {
        case let .ibkr(conid, title, currency):
            ["kind": "ibkr", "conid": conid, "title": title, "quote_currency": currency]
        case let .indianMutualFund(code, title):
            ["kind": "indian_mutual_fund", "scheme_code": code, "title": title]
        }
    }
}
