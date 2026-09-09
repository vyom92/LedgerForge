import Combine
import Foundation

@MainActor
final class SalaryWorkspaceViewModel: ObservableObject {
    enum MoneyField: String, CaseIterable { case fixed, variable, deductions, fee, investment }

    @Published private(set) var plan: FundingPlan
    @Published private(set) var calculation: FundingPlanCalculation
    @Published private(set) var errorMessage: String?
    @Published private(set) var rawText: [String: String] = [:]
    @Published private(set) var fieldErrors: [String: String] = [:]
    @Published private(set) var isDirty = false
    @Published private(set) var saveState: SaveState = .ready
    enum SaveState: Equatable { case ready, saving, saved, failed, committedNeedsRefresh, committedToPreviousProvider, providerChanged, canonicalChanged }
    private let locale: Locale
    private var baseGeneration: ProviderGenerationToken
    private var baseCanonical: FundingPlan?
    private var isRebasing = false
    private var committedCandidate: FundingPlan?
    private var baseRawText: [String: String] = [:]
    private var baseDraftPlan: FundingPlan?
    private var subscription: AnyCancellable?
    private let refresh: (DatabaseProvider) throws -> Void
    private let requiresApplicationAvailability: Bool

    var canEdit: Bool {
        ![.saving, .failed, .committedNeedsRefresh, .committedToPreviousProvider, .providerChanged, .canonicalChanged].contains(saveState) &&
        (!requiresApplicationAvailability || ApplicationAvailability.shared.permitsMutation)
    }
    var canSave: Bool {
        provider().persistenceState.isUsable && provider().generationToken == baseGeneration && fundingPlanStore.generation == baseGeneration &&
        (!requiresApplicationAvailability || ApplicationAvailability.shared.permitsMutation) &&
        ![.saving, .failed, .committedNeedsRefresh, .committedToPreviousProvider, .providerChanged, .canonicalChanged].contains(saveState) && fieldErrors.isEmpty
    }
    var statusText: String {
        switch saveState {
        case .saving: return "Saving…"
        case .saved: return "Saved"
        case .failed: return "Save outcome unavailable · reopen the app before retrying"
        case .committedNeedsRefresh: return "Saved · reload required"
        case .committedToPreviousProvider: return "Saved to the previous database · reload the current database"
        case .providerChanged: return "Database changed · discard this draft to reload"
        case .canonicalChanged: return "Saved plan changed · discard this draft to reload"
        case .ready: return isDirty ? "Unsaved changes" : "Ready"
        }
    }
    var hasValidCalculation: Bool { fieldErrors.isEmpty }
    var canRollover: Bool { fundingPlanStore.plan(for: month, workspaceID: workspaceID) == nil && fundingPlanStore.plans.contains { $0.workspaceID == workspaceID && $0.month < month } }


    private let month: SelectedStatementMonth
    private let workspaceID: String
    private let provider: () -> DatabaseProvider
    private let accountStore: AccountStore
    private let salaryStore: SalaryStore
    private let fundingPlanStore: FundingPlanStore

    init(
        month: SelectedStatementMonth? = nil,
        workspaceID: String = "default-workspace",
        provider: (() -> DatabaseProvider)? = nil,
        accountStore: AccountStore? = nil,
        salaryStore: SalaryStore? = nil,
        fundingPlanStore: FundingPlanStore? = nil,
        locale: Locale = .current,
        refresh: ((DatabaseProvider) throws -> Void)? = nil
    ) {
        let resolvedMonth = month ?? Self.currentMonth()
        let resolvedAccountStore = accountStore ?? .shared
        let resolvedSalaryStore = salaryStore ?? .shared
        let resolvedFundingPlanStore = fundingPlanStore ?? .shared
        self.month = resolvedMonth
        self.workspaceID = workspaceID
        self.provider = provider ?? { DatabaseProvider.shared }
        self.requiresApplicationAvailability = provider == nil && fundingPlanStore == nil
        self.locale = locale
        self.baseGeneration = (provider?() ?? DatabaseProvider.shared).generationToken
        self.refresh = refresh ?? { active in _ = try RepositoryStoreHydrator(databaseProvider: active).hydrateIfNeeded(forceRefresh: true) }
        self.accountStore = resolvedAccountStore
        self.salaryStore = resolvedSalaryStore
        self.fundingPlanStore = resolvedFundingPlanStore
        let canonicalIsCurrent = resolvedFundingPlanStore.generation == self.baseGeneration
        let initial = (canonicalIsCurrent ? resolvedFundingPlanStore.plan(for: resolvedMonth, workspaceID: workspaceID) : nil) ?? Self.emptyPlan(month: resolvedMonth, workspaceID: workspaceID)
        self.baseCanonical = canonicalIsCurrent ? resolvedFundingPlanStore.plan(for: resolvedMonth, workspaceID: workspaceID) : nil
        self.saveState = canonicalIsCurrent ? .ready : .providerChanged
        self.plan = initial
        self.calculation = FundingPlanCalculator.calculate(initial)
        syncDraft()
        captureDraftBase()
        self.subscription = resolvedFundingPlanStore.$plans.sink { [weak self] _ in self?.canonicalDidPublish() }
    }

    var statements: [SalaryStatement] { salaryStore.statements }
    var eligibleAccounts: [Account] {
        accountStore.accounts.filter(Self.isEligibleAccount).sorted { ($0.nativeCurrency.code, $0.name, $0.repositoryAccountId ?? "") < ($1.nativeCurrency.code, $1.name, $1.repositoryAccountId ?? "") }
    }

    var currentMonthActual: Money? {
        let values = statements.filter { $0.workspaceID == workspaceID && $0.evidence.financialPeriod == month }.map { $0.evidence.printedPaymentTotal }
        guard !values.isEmpty else { return nil }
        return try? Money.aggregate(values)
    }

    var historyGroups: [(month: SelectedStatementMonth, statements: [SalaryStatement], actual: Money)] {
        Dictionary(grouping: statements.filter { $0.workspaceID == workspaceID }, by: { $0.evidence.financialPeriod })
            .compactMap { period, values in
                guard let total = try? Money.aggregate(values.map { $0.evidence.printedPaymentTotal }) else { return nil }
                return (period, values.sorted { ($0.importedAtISO, $0.id) < ($1.importedAtISO, $1.id) }, total)
            }
            .sorted { $0.month > $1.month }
    }

    func moneyText(_ field: MoneyField) -> String {
        if let text = rawText[field.rawValue] { return text }
        let money: Money
        switch field {
        case .fixed: money = plan.expectedFixedEarnings
        case .variable: money = plan.expectedVariableEarnings
        case .deductions: money = plan.expectedDeductions
        case .fee: money = plan.configuredTransferFee
        case .investment: money = plan.plannedInvestment
        }
        return (try? money.canonicalDecimalString()) ?? ""
    }

    @discardableResult
    func updateMoney(_ field: MoneyField, text: String) -> Bool {
        guard canEdit else { return false }
        rawText[field.rawValue] = text
        markEdited()
        guard let value = validatedMoney(field, text: text) else { return false }
        switch field {
        case .fixed: plan.expectedFixedEarnings = value; plan.expectedFixedProvenance = .manual
        case .variable: plan.expectedVariableEarnings = value; plan.expectedVariableProvenance = .manual
        case .deductions: plan.expectedDeductions = value; plan.expectedDeductionsProvenance = .manual
        case .fee: plan.configuredTransferFee = value; plan.configuredTransferFeeProvenance = .manual
        case .investment: plan.plannedInvestment = value; plan.plannedInvestmentProvenance = .manual
        }
        recalculate()
        return true
    }

    func setFX(rateText: String, dateText: String) {
        guard canEdit else { return }
        rawText["fx.rate"] = rateText; rawText["fx.date"] = dateText
        markEdited()
        fieldErrors["fx.rate"] = nil; fieldErrors["fx.date"] = nil
        if rateText.isEmpty && dateText.isEmpty { plan.planningFX = nil; recalculate(); return }
        let rate = try? PlannerInputCodec.rate(rateText, locale: locale)
        let date = try? StatementDate(canonical: dateText)
        if rate == nil { fieldErrors["fx.rate"] = "Enter a complete positive INR-per-QAR rate" }
        if date == nil { fieldErrors["fx.date"] = "Enter the observation date as YYYY-MM-DD" }
        guard let rate, let date, let fx = try? FundingPlanFX(inrPerQAR: rate, observationDate: date) else { return }
        plan.planningFX = fx
        recalculate()
    }

    func setAccountIncluded(_ account: Account, included: Bool) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        markEdited()
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].included = included
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: included, money: nil, provenance: .manual))
        }
        recalculate()
    }

    func captureAccountBalance(_ account: Account) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        markEdited()
        rawText["balance.\(id)"] = (try? account.currentBalanceMoney.canonicalDecimalString()).map(localized) ?? ""
        fieldErrors["balance.\(id)"] = nil
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = account.currentBalanceMoney
            plan.balances[index].provenance = .capturedAccountBalance(capturedAtISO: capturedAt)
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: account.currentBalanceMoney, provenance: .capturedAccountBalance(capturedAtISO: capturedAt)))
        }
        recalculate()
    }

    func setManualBalance(_ account: Account, text: String) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        let key = "balance.\(id)"
        rawText[key] = text
        markEdited()
        guard let money = try? PlannerInputCodec.money(text, currency: account.nativeCurrency.code, locale: locale) else {
            fieldErrors[key] = "Enter an exact \(account.nativeCurrency.code) balance"
            return
        }
        fieldErrors[key] = nil
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = money
            plan.balances[index].provenance = .manual
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: money, provenance: .manual))
        }
        recalculate()
    }

    func addCommitment(region: String) {
        guard canEdit else { return }
        markEdited()
        let currency = region == "qatar" ? "QAR" : "INR"
        guard let zero = try? Money(canonicalDecimal: "0.00", currency: currency) else { return }
        let value = FundingPlanCommitment(id: UUID().uuidString, label: "New commitment", money: zero, included: true, fundingAccountID: nil, provenance: .manual)
        rawText["label.\(value.id)"] = value.label
        rawText["amount.\(value.id)"] = localized("0.00")
        if region == "qatar" { plan.qatarCommitments.append(value) }
        else { plan.indiaCommitments.append(value) }
        recalculate()
    }

    func updateCommitment(region: String, id: String, label: String, amountText: String, included: Bool, fundingAccountID: String?) {
        guard canEdit else { return }
        let currency = region == "qatar" ? "QAR" : "INR"
        rawText["label.\(id)"] = label; rawText["amount.\(id)"] = amountText
        markEdited()
        fieldErrors["label.\(id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a label of 1–240 characters" : nil
        let money = try? PlannerInputCodec.money(amountText, currency: currency, locale: locale)
        fieldErrors["amount.\(id)"] = money == nil ? "Enter an exact \(currency) amount" : nil
        var values = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = values.firstIndex(where: { $0.id == id }) else { return }
        let changedValue = values[index].label != label || (money != nil && values[index].money != money)
        values[index].label = label
        if let money { values[index].money = money }
        values[index].included = included
        values[index].fundingAccountID = fundingAccountID
        if changedValue { values[index].provenance = .manual }
        if region == "qatar" { plan.qatarCommitments = values } else { plan.indiaCommitments = values }
        recalculate()
    }

    func editCommitment(region: String, id: String, field: String, text: String) {
        guard let value = (region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments).first(where: { $0.id == id }) else { return }
        updateCommitment(region: region, id: id,
            label: field == "label" ? text : rawText["label.\(id)"] ?? value.label,
            amountText: field == "amount" ? text : rawText["amount.\(id)"] ?? "",
            included: field == "included" ? text == "true" : value.included,
            fundingAccountID: field == "account" ? (text.isEmpty ? nil : text) : value.fundingAccountID)
    }

    func removeCommitment(region: String, id: String) {
        guard canEdit else { return }
        markEdited()
        for key in ["label.\(id)", "amount.\(id)"] { rawText[key] = nil; fieldErrors[key] = nil }
        if region == "qatar" { plan.qatarCommitments.removeAll { $0.id == id } }
        else { plan.indiaCommitments.removeAll { $0.id == id } }
        recalculate()
    }

    func rolloverFromPreviousPlan(discardingDraft: Bool = false) {
        guard canEdit else { return }
        guard !isDirty || discardingDraft else { errorMessage = "Choose whether to discard the unsaved draft before copying the previous plan."; return }
        guard fundingPlanStore.plan(for: month, workspaceID: workspaceID) == nil,
              let previous = fundingPlanStore.plans.filter({ $0.workspaceID == workspaceID && $0.month < month }).max(by: { $0.month < $1.month }) else {
            errorMessage = "No earlier editable plan is available to roll forward, or this month already exists."
            return
        }
        let source = previous.id
        plan = FundingPlan(
            id: UUID().uuidString,
            workspaceID: workspaceID,
            month: month,
            rolloverSourcePlanID: source,
            expectedFixedEarnings: previous.expectedFixedEarnings,
            expectedFixedProvenance: .carried(sourcePlanID: source),
            expectedVariableEarnings: previous.expectedVariableEarnings,
            expectedVariableProvenance: .carried(sourcePlanID: source),
            expectedDeductions: previous.expectedDeductions,
            expectedDeductionsProvenance: .carried(sourcePlanID: source),
            balances: previous.balances.map { FundingPlanBalance(id: UUID().uuidString, accountID: $0.accountID, nativeCurrency: $0.nativeCurrency, included: $0.included, money: $0.money, provenance: .carried(sourcePlanID: source)) },
            qatarCommitments: previous.qatarCommitments.map { FundingPlanCommitment(id: UUID().uuidString, label: $0.label, money: $0.money, included: $0.included, fundingAccountID: $0.fundingAccountID, provenance: .carried(sourcePlanID: source)) },
            indiaCommitments: previous.indiaCommitments.map { FundingPlanCommitment(id: UUID().uuidString, label: $0.label, money: $0.money, included: $0.included, fundingAccountID: $0.fundingAccountID, provenance: .carried(sourcePlanID: source)) },
            configuredTransferFee: previous.configuredTransferFee,
            configuredTransferFeeProvenance: .carried(sourcePlanID: source),
            planningFX: previous.planningFX,
            plannedInvestment: previous.plannedInvestment,
            plannedInvestmentProvenance: .carried(sourcePlanID: source),
            updatedAtISO: ISO8601DateFormatter().string(from: Date())
        )
        syncDraft()
        markEdited()
        recalculate()
    }

    func save() {
        canonicalDidPublish()
        guard canSave else { errorMessage = fieldErrors.isEmpty ? statusText : "Correct the marked fields before saving."; return }
        // All visible strings are already owned here, including the currently focused field.
        validateVisibleDraft()
        guard fieldErrors.isEmpty else { errorMessage = "Correct the marked fields before saving."; return }
        let active = provider()
        guard active.generationToken == baseGeneration else { saveState = .providerChanged; return }
        saveState = .saving
        plan.updatedAtISO = ISO8601DateFormatter().string(from: Date())
        do {
            _ = try active.fundingPlanRepo.savePlan(try Self.dto(from: plan))
        } catch {
            saveState = .failed
            let failure = RuntimeDiagnostic.failure(error, operation: "plan save", stage: "repository transaction")
            errorMessage = failure.summary + ". " + failure.nextAction
            RuntimeDiagnostic.record(failure, category: .database)
            return
        }
        committedCandidate = plan
        isDirty = false
        saveState = .committedNeedsRefresh
        retryCanonicalRefresh()
    }

    func retryCanonicalRefresh() {
        guard saveState == .committedNeedsRefresh else { return }
        let active = provider()
        guard active.generationToken == baseGeneration else { saveState = .committedToPreviousProvider; return }
        do {
            try refresh(active)
            guard let canonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID), canonical == committedCandidate, provider().generationToken == baseGeneration, fundingPlanStore.generation == baseGeneration else { throw RepositoryStoreHydrationError.invalidFundingPlanState("saved plan missing") }
            plan = canonical; baseCanonical = canonical
            syncDraft(); captureDraftBase(); saveState = .saved; errorMessage = nil
            DeveloperConsole.shared.info(.database, "Funding plan saved and reloaded", metadata: ["code": "plan.saved", "effect": "committed and canonical data current"])
        } catch {
            saveState = .committedNeedsRefresh
            let failure = RuntimeDiagnostic.failure(error, operation: "plan save", stage: "post-commit canonical reload", effect: "plan committed; runtime data not current")
            errorMessage = "The plan was saved. Reload canonical data before editing again."
            RuntimeDiagnostic.record(failure, category: .runtime)
        }
    }

    func discardAndReload() {
        let active = provider()
        isRebasing = true
        defer { isRebasing = false }
        do {
            try refresh(active)
            guard provider().generationToken == active.generationToken, fundingPlanStore.generation == active.generationToken else { throw RepositoryError.staleProviderGeneration }
            rebaseFromPublishedPlan(generation: active.generationToken)
        } catch {
            errorMessage = "Canonical data could not be reloaded. Your draft is retained."
            saveState = .providerChanged
        }
    }

    private func rebaseFromPublishedPlan(generation: ProviderGenerationToken) {
        baseGeneration = generation
        baseCanonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID)
        plan = baseCanonical ?? Self.emptyPlan(month: month, workspaceID: workspaceID)
        isDirty = false; saveState = .ready; errorMessage = nil
        syncDraft(); captureDraftBase(); recalculate()
    }

    private func canonicalDidPublish() {
        guard !isRebasing && saveState != .saving else { return }
        let changedProvider = provider().generationToken != baseGeneration
        if saveState == .committedNeedsRefresh {
            if changedProvider { saveState = .committedToPreviousProvider }
            else if fundingPlanStore.generation == baseGeneration, fundingPlanStore.plan(for: month, workspaceID: workspaceID) == committedCandidate {
                plan = committedCandidate!; baseCanonical = plan
                syncDraft(); captureDraftBase(); saveState = .saved; errorMessage = nil
            }
            return
        }
        let canonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID)
        guard changedProvider || canonical != baseCanonical || fundingPlanStore.generation != baseGeneration else { return }
        if isDirty { saveState = changedProvider ? .providerChanged : .canonicalChanged }
        else if fundingPlanStore.generation == provider().generationToken {
            rebaseFromPublishedPlan(generation: provider().generationToken)
        } else { saveState = .providerChanged }
    }

    private func captureDraftBase() { baseRawText = rawText; baseDraftPlan = plan; isDirty = false }

    private func markEdited() {
        isDirty = rawText != baseRawText || plan != baseDraftPlan
        if [.ready, .saved, .failed].contains(saveState) { saveState = .ready }
        errorMessage = nil
    }

    private func localized(_ text: String) -> String {
        var compact = text
        if compact.contains(".") { while compact.hasSuffix("0") { compact.removeLast() }; if compact.hasSuffix(".") { compact.removeLast() } }
        return compact.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
    private func syncDraft() {
        rawText = [:]; fieldErrors = [:]
        for field in MoneyField.allCases { rawText[field.rawValue] = localized(moneyText(field)) }
        rawText["fx.rate"] = plan.planningFX.map { localized(NSDecimalNumber(decimal: $0.inrPerQAR).stringValue) } ?? ""
        rawText["fx.date"] = plan.planningFX?.observationDate.canonical ?? ""
        for balance in plan.balances { rawText["balance.\(balance.accountID)"] = (try? balance.money?.canonicalDecimalString()).map(localized) ?? "" }
        for value in plan.qatarCommitments + plan.indiaCommitments {
            rawText["label.\(value.id)"] = value.label
            rawText["amount.\(value.id)"] = (try? value.money.canonicalDecimalString()).map(localized) ?? ""
        }
    }

    /// Editing and final Save must apply the same field-specific constraints.
    private func validatedMoney(_ field: MoneyField, text: String) -> Money? {
        guard let value = try? PlannerInputCodec.money(text, currency: "QAR", locale: locale) else {
            fieldErrors[field.rawValue] = "Enter an exact QAR amount with up to two decimals"
            return nil
        }
        guard field != .fee || value.amount >= 0 else {
            fieldErrors[field.rawValue] = "Transfer fee must be zero or greater"
            return nil
        }
        fieldErrors[field.rawValue] = nil
        return value
    }

    private func validateVisibleDraft() {
        for field in MoneyField.allCases {
            _ = validatedMoney(field, text: moneyText(field))
        }
        // FX has no separate commit state; both fields were parsed together on every edit.
        for account in eligibleAccounts {
            if let id = account.repositoryAccountId, let text = rawText["balance.\(id)"], !text.isEmpty {
                // Validation must not turn a captured or carried balance into a manual value.
                fieldErrors["balance.\(id)"] = (try? PlannerInputCodec.money(text, currency: account.nativeCurrency.code, locale: locale)) == nil ? "Enter an exact balance" : nil
            }
        }
        for (region, values) in [("qatar", plan.qatarCommitments), ("india", plan.indiaCommitments)] {
            for value in values {
                let label = rawText["label.\(value.id)"] ?? ""
                fieldErrors["label.\(value.id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a label of 1–240 characters" : nil
                let amount = rawText["amount.\(value.id)"] ?? ""
                fieldErrors["amount.\(value.id)"] = (try? PlannerInputCodec.money(amount, currency: region == "qatar" ? "QAR" : "INR", locale: locale)) == nil ? "Enter an exact amount" : nil
            }
        }
    }

    func provenanceText(_ value: FundingPlanValueProvenance) -> String {
        switch value {
        case .manual: return "Your estimate"
        case .capturedAccountBalance(let time): return "Captured from account · \(time)"
        case .carried(let id): return fundingPlanStore.plans.first(where: { $0.id == id }).map { "Copied from \($0.month.canonical)" } ?? "Copied from an earlier plan"
        }
    }

    func dismissError() { errorMessage = nil }

    private func recalculate() { calculation = FundingPlanCalculator.calculate(plan); if saveState != .committedNeedsRefresh { isDirty = rawText != baseRawText || plan != baseDraftPlan } }

    private static func currentMonth(now: Date = Date()) -> SelectedStatementMonth {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: now)
        return try! SelectedStatementMonth(year: parts.year!, month: parts.month!)
    }

    private static func emptyPlan(month: SelectedStatementMonth, workspaceID: String) -> FundingPlan {
        let zero = try! Money(canonicalDecimal: "0.00", currency: "QAR")
        let fee = try! Money(canonicalDecimal: "25.00", currency: "QAR")
        return FundingPlan(id: UUID().uuidString, workspaceID: workspaceID, month: month, rolloverSourcePlanID: nil,
                           expectedFixedEarnings: zero, expectedFixedProvenance: .manual,
                           expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
                           expectedDeductions: zero, expectedDeductionsProvenance: .manual,
                           balances: [], qatarCommitments: [], indiaCommitments: [],
                           configuredTransferFee: fee, configuredTransferFeeProvenance: .manual,
                           planningFX: nil, plannedInvestment: zero, plannedInvestmentProvenance: .manual,
                           updatedAtISO: ISO8601DateFormatter().string(from: Date()))
    }

    private static func isEligibleAccount(_ account: Account) -> Bool {
        guard account.status == .active, account.type == .bank, account.repositoryAccountId != nil else { return false }
        if account.nativeCurrency.code == "QAR" { return account.institution == Institution.cbq.rawValue }
        guard account.nativeCurrency.code == "INR", [Institution.axis.rawValue, Institution.hdfc.rawValue].contains(account.institution) else { return false }
        let name = "\(account.name) \(account.nickname ?? "")".uppercased()
        return name.contains("NRE") || name.contains("NRO")
    }

    private static func dto(from plan: FundingPlan) throws -> FundingPlanDTO {
        func provenance(_ value: FundingPlanValueProvenance) -> (code: String, carried: String?, captured: String?) {
            switch value {
            case .manual: return ("manual", nil, nil)
            case .carried(let source): return ("carried", source, nil)
            case .capturedAccountBalance(let time): return ("captured_account_balance", nil, time)
            }
        }
        func amount(_ money: Money) throws -> (Int64, String) { (try money.minorUnits(), try money.canonicalDecimalString()) }
        let fixed = try amount(plan.expectedFixedEarnings), variable = try amount(plan.expectedVariableEarnings)
        let deductions = try amount(plan.expectedDeductions), fee = try amount(plan.configuredTransferFee)
        let investment = try amount(plan.plannedInvestment)
        let balances = try plan.balances.enumerated().map { index, value -> FundingPlanBalanceDTO in
            let p = provenance(value.provenance)
            return FundingPlanBalanceDTO(id: value.id, planId: plan.id, sourceOrdinal: index + 1, accountId: value.accountID, nativeCurrency: value.nativeCurrency.code, included: value.included,
                                         amountCurrency: value.money?.currency.code, amountMinor: try value.money?.minorUnits(), amountDecimal: try value.money?.canonicalDecimalString(),
                                         provenanceCode: p.code, carriedSourcePlanId: p.carried, capturedAtISO: p.captured)
        }
        func commitmentDTOs(_ values: [FundingPlanCommitment], region: String) throws -> [FundingPlanCommitmentDTO] {
            try values.enumerated().map { index, value in
                let p = provenance(value.provenance), money = try amount(value.money)
                return FundingPlanCommitmentDTO(id: value.id, planId: plan.id, regionCode: region, sourceOrdinal: index + 1, label: value.label,
                                                amountCurrency: value.money.currency.code, amountMinor: money.0, amountDecimal: money.1,
                                                included: value.included, fundingAccountId: value.fundingAccountID,
                                                provenanceCode: p.code, carriedSourcePlanId: p.carried)
            }
        }
        return FundingPlanDTO(
            id: plan.id, workspaceId: plan.workspaceID, planMonthISO: plan.month.canonical, rolloverSourcePlanId: plan.rolloverSourcePlanID,
            expectedFixedMinor: fixed.0, expectedFixedDecimal: fixed.1, expectedFixedProvenance: provenance(plan.expectedFixedProvenance).code,
            expectedVariableMinor: variable.0, expectedVariableDecimal: variable.1, expectedVariableProvenance: provenance(plan.expectedVariableProvenance).code,
            expectedDeductionsMinor: deductions.0, expectedDeductionsDecimal: deductions.1, expectedDeductionsProvenance: provenance(plan.expectedDeductionsProvenance).code,
            configuredFeeMinor: fee.0, configuredFeeDecimal: fee.1, configuredFeeProvenance: provenance(plan.configuredTransferFeeProvenance).code,
            fxINRPerQARDecimal: plan.planningFX.map { NSDecimalNumber(decimal: $0.inrPerQAR).stringValue }, fxObservationDateISO: plan.planningFX?.observationDate.canonical,
            plannedInvestmentMinor: investment.0, plannedInvestmentDecimal: investment.1, plannedInvestmentProvenance: provenance(plan.plannedInvestmentProvenance).code,
            updatedAtISO: plan.updatedAtISO, balances: balances,
            commitments: try commitmentDTOs(plan.qatarCommitments, region: "qatar") + commitmentDTOs(plan.indiaCommitments, region: "india")
        )
    }
}
