import Foundation

/// One synchronous planning publication. The lifecycle lease and native editor
/// reservation span the repository transaction and canonical hydration; a lost
/// HTTP response cannot cancel a committed edit or change its retry identity.
@MainActor
final class FinancialMCPPlanningWriteService {
    static let shared = FinancialMCPPlanningWriteService()
    private let provider: () -> DatabaseProvider
    private let store: FundingPlanStore
    private let hydrate: (DatabaseProvider) throws -> Void
    private let now: () -> Date
    private let inputLocale: Locale
    private let requiresApplicationAvailability: Bool

    init(provider: (() -> DatabaseProvider)? = nil, store: FundingPlanStore? = nil,
         hydrate: ((DatabaseProvider) throws -> Void)? = nil, now: @escaping () -> Date = Date.init,
         inputLocale: Locale = .current) {
        self.provider = provider ?? { .shared }
        self.store = store ?? .shared
        self.hydrate = hydrate ?? { active in
            _ = try RepositoryStoreHydrator(databaseProvider: active).hydrateIfNeeded(forceRefresh: true)
        }
        self.now = now
        self.inputLocale = inputLocale
        self.requiresApplicationAvailability = provider == nil
    }

    /// Additive read context, independent of dashboard and investment prices.
    /// Never attach a fresh precondition to older presentation values.
    func writeContext(workspaceID: String, month: SelectedStatementMonth,
                      saved: FundingPlan?, retained: MonthlyPlanScratchpad?) -> [String: Any] {
        do {
            let lease = try DatabaseActivityGate.shared.begin(.hydration)
            defer { lease.finish() }
            let active = provider()
            try requireAvailable(active)
            guard let saved, saved.calculationVersion == .budgetV1,
                  saved.workspaceID == workspaceID, saved.month == month,
                  store.generation == active.generationToken else {
                return unavailableContext("canonical_plan_unavailable")
            }
            let snapshot = try active.fundingPlanRepo.planningWriteSnapshot(workspaceID: workspaceID, month: month.canonical)
            guard try snapshot.plan == saved.persistenceDTO(),
                  try snapshot.scratchpad.map(MonthlyPlanScratchpad.decode) == retained else {
                return unavailableContext("canonical_presentation_changed")
            }
            if let conflict = SalaryWorkspaceViewModel.planningWriteConflict(workspaceID: workspaceID, month: month, provider: active) {
                return unavailableContext("draft_conflict", message: conflict)
            }
            try Self.requireCleanRetained(snapshot, canonical: saved)
            return Self.context(snapshot)
        } catch { return unavailableContext(Self.errorCode(error), message: Self.message(error)) }
    }

    func apply(_ request: PlanningChangeRequest) -> [String: Any] {
        var receiptResolved = false
        do {
            // Decode even value-constructed requests at this public boundary.
            let request = try PlanningChangeRequest.decode(request.canonicalData())
            let digest = try request.digestSHA256()
            let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
            defer { lease.finish() }
            let active = provider()
            if let previous = try active.fundingPlanRepo.planningRequestReceipt(requestID: request.requestID) {
                receiptResolved = true
                guard previous.requestDigest == digest else { throw PlanningWriteError.requestIDConflict }
                return finish(previous, replayed: true, provider: active)
            }
            receiptResolved = true
            try requireAvailable(active)
            guard store.generation == active.generationToken else { throw PlanningWriteError.unavailableContext }
            return try SalaryWorkspaceViewModel.withPlanningWriteReservation(
                workspaceID: request.workspaceID, month: request.month, provider: active
            ) {
                let commit = PlanningChangeCommitRequest(requestID: request.requestID, requestDigest: digest,
                    workspaceID: request.workspaceID, month: request.month.canonical, planID: request.planID,
                    expectedWriteRevision: request.expectedWriteRevision,
                    committedAtISO: ISO8601DateFormatter().string(from: now()))
                let receipt = try active.fundingPlanRepo.commitPlanningChange(commit) { snapshot in
                    guard let dto = snapshot.plan, dto.id == request.planID,
                          dto.workspaceId == request.workspaceID, dto.planMonthISO == request.month.canonical,
                          let financial = snapshot.financial else { throw PlanningWriteError.unavailableContext }
                    let original = try dto.allocationCalculationInput()
                    guard original.calculationVersion == .budgetV1 else { throw PlanningWriteError.unsupportedPlan }
                    guard self.store.plan(for: request.month, workspaceID: request.workspaceID) == original else {
                        throw PlanningWriteError.unavailableContext
                    }
                    try Self.requireCleanRetained(snapshot, canonical: original)
                    let salaryReceipt = try PayslipReceiptState.resolve(plan: original,
                        receiptDTOs: snapshot.receiptTransactions,
                        excludedAccounts: financial.preferences?.excludedPlanningAccountIDs ?? [])
                    var candidate = try PlanningChangeApplicator.apply(request.changes, to: original,
                        snapshot: financial, accounts: snapshot.accounts, productLabels: snapshot.productLabels,
                        salaryReceipt: salaryReceipt)
                    let changed = candidate != original
                    if changed { candidate.updatedAtISO = commit.committedAtISO }
                    let raw = changed
                        ? try Self.retained(candidate, replacing: snapshot.scratchpad,
                            inputLocale: self.inputLocale,
                            paired: snapshot.activeCompanionSession != nil && snapshot.companionMonth != nil).dto()
                        : snapshot.scratchpad
                    let result = try PlanningWriteReceiptContent.make(request: request, before: original, after: candidate)
                    let companion = try changed ? raw.map { raw in
                        try CompanionMacCoordinator.planningWriteCompanionRequest(snapshot: snapshot,
                            scratchpad: MonthlyPlanScratchpad.decode(raw), provider: active)
                    } ?? nil : nil
                    return PlanningChangeCommitCandidate(plan: try candidate.persistenceDTO(), scratchpad: raw,
                        resultJSON: String(decoding: FinancialMCPProtocol.encode(result), as: UTF8.self),
                        companionRequest: companion)
                }
                return finish(receipt, replayed: false, provider: active)
            }
        } catch {
            var result: [String: Any] = [
                "request_id": request.requestID, "outcome": "rejected", "changes": [],
                "error": ["code": Self.errorCode(error), "message": Self.message(error)],
                "next_action": "Read current planning context and reconcile the requested changes."
            ]
            if receiptResolved { result["mutation_performed"] = false }
            else {
                result["outcome"] = "unavailable"
                result["prior_attempt_status"] = "unknown"
                result["next_action"] = "Retry the identical request ID and arguments when the provider is available."
            }
            return result
        }
    }

    private func finish(_ receipt: PlanningRequestReceipt, replayed: Bool, provider active: DatabaseProvider) -> [String: Any] {
        var result = FinancialMCPProtocol.object(Data(receipt.resultJSON.utf8)) ?? [:]
        result["request_id"] = receipt.requestID
        result["workspace_id"] = receipt.workspaceID
        result["month"] = receipt.month
        result["plan_id"] = receipt.planID
        result["outcome"] = receipt.outcome == .saved ? "applied" : "no_change"
        result["committed"] = true
        result["replayed"] = replayed
        result["committed_month_revision"] = receipt.committedMonthRevision
        result["committed_at"] = receipt.committedAtISO
        result["receipt_basis"] = replayed ? "Historical committed result; current values are reported separately." : "Committed request result."
        do {
            try hydrate(active)
            guard provider().generationToken == active.generationToken,
                  store.generation == active.generationToken else { throw PlanningWriteError.unavailableContext }
            let snapshot = try active.fundingPlanRepo.planningWriteSnapshot(workspaceID: receipt.workspaceID, month: receipt.month)
            guard let dto = snapshot.plan, dto.id == receipt.planID,
                  let month = try? SelectedStatementMonth(canonical: receipt.month) else { throw PlanningWriteError.unavailableContext }
            let current = try dto.allocationCalculationInput()
            guard store.plan(for: month, workspaceID: receipt.workspaceID) == current else { throw PlanningWriteError.unavailableContext }
            result["canonical_saved_origin"] = snapshot.monthRevision.latestOrigin.rawValue
            result["canonical_readback"] = [
                "state": "verified", "month_revision": String(snapshot.monthRevision.counter),
                "plan": try FinancialMCPPresentation.plan(current)
            ]
            let salaryReceipt = try PayslipReceiptState.resolve(plan: current, receiptDTOs: snapshot.receiptTransactions,
                excludedAccounts: snapshot.financial?.preferences?.excludedPlanningAccountIDs ?? [])
            result["calculated_outputs"] = FinancialMCPPresentation.calculation(FundingPlanCalculator.calculate(current,
                excludingAccounts: snapshot.financial?.preferences?.excludedPlanningAccountIDs ?? [],
                historyOnlyAccountIDs: Set(snapshot.accounts.filter { $0.closedAtISO != nil }.map(\.id)),
                salaryReceipt: salaryReceipt))
            result["write_context"] = writeContext(workspaceID: receipt.workspaceID, month: month,
                saved: current, retained: try snapshot.scratchpad.map(MonthlyPlanScratchpad.decode))
        } catch {
            result["outcome"] = "committed_refresh_needed"
            result["canonical_readback"] = ["state": "unavailable"]
            result["write_context"] = unavailableContext("canonical_refresh_needed")
            result["next_action"] = "The request committed. Retry this identical request to recover its receipt and refresh current canonical data."
        }
        return result
    }

    private func requireAvailable(_ active: DatabaseProvider) throws {
        guard !requiresApplicationAvailability || (ApplicationAvailability.shared.permitsMutation
            && ApplicationAvailability.shared.generation == active.generationToken) else { throw PlanningWriteError.unavailable }
    }

    private static func requireCleanRetained(_ snapshot: PlanningWriteSnapshot, canonical: FundingPlan) throws {
        guard let raw = snapshot.scratchpad else { return }
        let scratch = try MonthlyPlanScratchpad.decode(raw)
        guard scratch.plan == canonical, scratch.canonical == canonical, scratch.fieldErrors.isEmpty else {
            throw PlanningNativeWriteError.draftConflict("The month has retained or incomplete entries. Review them in Budget Planning before writing.")
        }
    }

    private static func context(_ snapshot: PlanningWriteSnapshot) -> [String: Any] {
        guard let plan = snapshot.plan, let revision = snapshot.writeRevision else {
            return ["state": "unavailable", "reason": "dependency_context_unavailable"]
        }
        return ["state": "available", "workspace_id": plan.workspaceId, "month": plan.planMonthISO,
                "plan_id": plan.id, "month_revision": String(snapshot.monthRevision.counter),
                "write_revision": revision, "canonical_saved_origin": snapshot.monthRevision.latestOrigin.rawValue]
    }

    private func unavailableContext(_ reason: String, message: String? = nil) -> [String: Any] {
        var value: [String: Any] = ["state": "unavailable", "reason": reason]
        if let message { value["message"] = message }
        return value
    }

    private static func errorCode(_ error: Error) -> String {
        if case PlanningNativeWriteError.draftConflict = error { return "draft_conflict" }
        if let error = error as? PlanningWriteError {
            switch error {
            case .staleRevision: return "stale_revision"
            case .requestIDConflict: return "request_id_conflict"
            case .unsupportedPlan: return "unsupported_scope"
            case .unavailableContext: return "context_unavailable"
            default: return "provider_unavailable"
            }
        }
        if let error = error as? SurplusAllocationError {
            switch error {
            case .unsupportedRoute: return "unsupported_route"
            case .invalidFundingLink: return "invalid_funding_link"
            case .exceedsCapacity: return "insufficient_capacity"
            case .invalidInstrument: return "invalid_instrument"
            default: return "invalid_allocation"
            }
        }
        if error is PlanningChangeError { return "invalid_change" }
        return "validation_failed"
    }

    private static func message(_ error: Error) -> String {
        if case PlanningNativeWriteError.draftConflict(let detail) = error { return detail }
        if error is PlanningChangeError || error is SurplusAllocationError { return String(describing: error) }
        if case PlanningWriteError.staleRevision = error { return "The target month or its planning dependencies changed after the supplied write context." }
        if case PlanningWriteError.requestIDConflict = error { return "This request ID already identifies a different committed request." }
        return "The planning operation could not establish a current valid canonical save."
    }

    /// Keep untouched lexical values. Changed values use the native locale in
    /// an ordinary month; paired publication records changed values as POSIX.
    static func retained(_ plan: FundingPlan, replacing raw: MonthlyPlanScratchpadDTO?,
                         inputLocale: Locale = .current, paired: Bool = false) throws -> MonthlyPlanScratchpad {
        let prior = try raw.map(MonthlyPlanScratchpad.decode)
        var result = prior ?? MonthlyPlanScratchpad(plan: plan, canonical: plan, rawText: [:], fieldErrors: [:],
            untouchedZeroFields: [], unavailableBalanceAccountIDs: [], preReductionBasis: [:], excludedRecurringOccurrenceIDs: [])
        let old = prior?.plan
        let decimalSeparator = paired ? "." : (inputLocale.decimalSeparator ?? ".")
        func localized(_ canonical: String) -> String {
            canonical.replacingOccurrences(of: ".", with: decimalSeparator)
        }
        func put(_ key: String, _ money: Money?, old oldMoney: Money?) throws {
            if old == nil || money != oldMoney {
                result.rawText[key] = try money.map { localized(try $0.canonicalDecimalString()) } ?? ""
                result.fieldErrors[key] = nil; result.untouchedZeroFields.remove(key)
            }
        }
        try put("fixed", plan.expectedFixedEarnings, old: old?.expectedFixedEarnings)
        try put("variable", plan.expectedVariableEarnings, old: old?.expectedVariableEarnings)
        try put("deductions", plan.expectedDeductions, old: old?.expectedDeductions)
        try put("fee", plan.configuredTransferFee, old: old?.configuredTransferFee)
        try put("reserve", plan.keepInCBQ, old: old?.keepInCBQ)
        try put("investment", plan.plannedInvestment, old: old?.plannedInvestment)
        if old == nil || plan.planningFX != old?.planningFX {
            result.rawText["fx.rate"] = plan.planningFX.map { localized(NSDecimalNumber(decimal: $0.inrPerQAR).stringValue) } ?? ""
            result.rawText["fx.date"] = plan.planningFX?.observationDate.canonical ?? ""
        }
        for row in plan.balances {
            try put("balance.\(row.accountID)", row.money, old: old?.balances.first { $0.id == row.id }?.money)
            if row.money != nil { result.unavailableBalanceAccountIDs.remove(row.accountID) }
        }
        for row in plan.deductions {
            try put("deduction.amount.\(row.id)", row.money, old: old?.deductions.first { $0.id == row.id }?.money)
            result.rawText["deduction.label.\(row.id)"] = row.label
        }
        let oldBills = (old?.qatarCommitments ?? []) + (old?.indiaCommitments ?? [])
        for row in plan.qatarCommitments + plan.indiaCommitments {
            try put("amount.\(row.id)", row.money, old: oldBills.first { $0.id == row.id }?.money)
            result.rawText["label.\(row.id)"] = row.label
        }
        // Native allocation inputs prefer retained text over the canonical row.
        // Invalidate only fields replaced by this publication, leaving unrelated
        // lexical choices and row identity available for the next native edit.
        func clear(_ row: AllocationRowID, _ field: AllocationEditorField) {
            let key = row.fieldKey(field)
            result.rawText[key] = nil
            result.fieldErrors[key] = nil
            result.untouchedZeroFields.remove(key)
        }
        func clearRow(_ row: AllocationRowID) {
            for key in result.rawText.keys.filter({ $0.hasPrefix(row.fieldPrefix) }) { result.rawText[key] = nil }
            for key in result.fieldErrors.keys.filter({ $0.hasPrefix(row.fieldPrefix) }) { result.fieldErrors[key] = nil }
            result.untouchedZeroFields = result.untouchedZeroFields.filter { !$0.hasPrefix(row.fieldPrefix) }
        }
        let previousContributions = Dictionary(uniqueKeysWithValues: (old?.assistance?.contributions ?? []).map { ($0.id, $0) })
        let currentContributions = Dictionary(uniqueKeysWithValues: (plan.assistance?.contributions ?? []).map { ($0.id, $0) })
        for (id, _) in previousContributions where currentContributions[id] == nil { clearRow(.contribution(id)) }
        for (id, current) in currentContributions {
            let row = AllocationRowID.contribution(id)
            guard let previous = previousContributions[id] else { clearRow(row); continue }
            if current.amount != previous.amount { clear(row, .amount) }
            if current.dueDate != previous.dueDate { clear(row, .date) }
            if current.fundingAccountID != previous.fundingAccountID { clear(row, .fundingAccount) }
            if current.fundingTransferID != previous.fundingTransferID { clear(row, .fundingTransfer) }
        }
        let previousTransfers = Dictionary(uniqueKeysWithValues: (old?.assistance?.transfers ?? []).map { ($0.id, $0) })
        let currentTransfers = Dictionary(uniqueKeysWithValues: (plan.assistance?.transfers ?? []).map { ($0.id, $0) })
        for (id, _) in previousTransfers where currentTransfers[id] == nil { clearRow(.transfer(id)) }
        for (id, current) in currentTransfers {
            let row = AllocationRowID.transfer(id)
            guard let previous = previousTransfers[id] else { clearRow(row); continue }
            if current.sent != previous.sent { clear(row, .amount) }
            if current.received != previous.received { clear(row, .received) }
            if current.date != previous.date { clear(row, .date) }
            if current.requiredIndiaFunding != previous.requiredIndiaFunding { clear(row, .requiredIndiaFunding) }
            if current.fromAccountID != previous.fromAccountID { clear(row, .fundingAccount) }
            if current.toAccountID != previous.toAccountID { clear(row, .destinationAccount) }
            if current.fundingTransferID != previous.fundingTransferID { clear(row, .fundingTransfer) }
        }
        let previousInvestments = Dictionary(uniqueKeysWithValues: (old?.assistance?.surplusAllocation?.investments ?? []).map { ($0.id, $0) })
        let currentInvestments = Dictionary(uniqueKeysWithValues: (plan.assistance?.surplusAllocation?.investments ?? []).map { ($0.id, $0) })
        func instrumentInputs(_ value: PlannedInvestmentInstrument) -> (id: String, title: String, quoteCurrency: String) {
            switch value {
            case .ibkr(let id, let title, let quoteCurrency): return (id, title, quoteCurrency)
            case .indianMutualFund(let id, let title): return (id, title, "INR")
            }
        }
        for (id, _) in previousInvestments where currentInvestments[id] == nil { clearRow(.investment(id)) }
        for (id, current) in currentInvestments {
            let row = AllocationRowID.investment(id)
            guard let previous = previousInvestments[id] else { clearRow(row); continue }
            if current.amount != previous.amount { clear(row, .amount) }
            if current.date != previous.date { clear(row, .date) }
            if current.fundingAccountID != previous.fundingAccountID { clear(row, .fundingAccount) }
            if current.fundingTransferID != previous.fundingTransferID { clear(row, .fundingTransfer) }
            let oldInstrument = instrumentInputs(previous.instrument)
            let newInstrument = instrumentInputs(current.instrument)
            if oldInstrument.id != newInstrument.id { clear(row, .instrumentID) }
            if oldInstrument.title != newInstrument.title { clear(row, .instrumentTitle) }
            if oldInstrument.quoteCurrency != newInstrument.quoteCurrency { clear(row, .quoteCurrency) }
        }
        result.plan = plan; result.canonical = plan
        return result
    }
}
