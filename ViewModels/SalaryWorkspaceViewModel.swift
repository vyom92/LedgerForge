import Combine
import Foundation

@MainActor
final class SalaryWorkspaceViewModel: ObservableObject {
    enum MoneyField: String, CaseIterable { case fixed, variable, deductions, fee, investment, reserve }

    @Published private(set) var plan: FundingPlan
    @Published private(set) var calculation: FundingPlanCalculation
    @Published private(set) var errorMessage: String?
    @Published private(set) var rawText: [String: String] = [:]
    @Published private(set) var fieldErrors: [String: String] = [:]
    @Published private(set) var unavailableCurrentBalanceAccountIDs: Set<String> = []
    @Published private var untouchedZeroFields: Set<String> = []
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
    private var calendarSubscription: AnyCancellable?
    private let now: () -> Date
    private let refresh: (DatabaseProvider) throws -> Void
    private let requiresApplicationAvailability: Bool
    private var sharedINRReference: AlDarUnitReference?
    private var hasOpenedPlanner = false
    /// Session-only value before a reduction. The one-month exception can be
    /// selected either before or after editing the remaining bill.
    private var preReductionBasis: [String: Money] = [:]
    private struct MonthDraftState {
        let plan: FundingPlan
        let raw: [String: String]
        let errors: [String: String]
        let untouched: Set<String>
        let unavailable: Set<String>
        let generation: ProviderGenerationToken
        let canonical: FundingPlan?
        let baseRaw: [String: String]
        let basePlan: FundingPlan?
        let dirty: Bool
        var saveState: SaveState
        let error: String?
        let committed: FundingPlan?
        let preReductionBasis: [String: Money]
    }
    private var monthDrafts: [SelectedStatementMonth: MonthDraftState] = [:]
    static let firstPlanningMonth = try! SelectedStatementMonth(year: 2026, month: 9)
    static let planningMonths = firstPlanningMonth...(try! SelectedStatementMonth(year: 2099, month: 12))
    private static var zeroQAR: Money { try! Money(canonicalDecimal: "0.00", currency: "QAR") }
    var visibleMoneyFields: [MoneyField] { plan.calculationVersion == .budgetV1 ? [.fixed, .variable, .reserve, .fee] : [.fixed, .variable, .deductions, .fee, .investment] }
    @Published private(set) var currentPlanningMonth: SelectedStatementMonth
    var nextPlanningMonth: SelectedStatementMonth { Self.nextMonth(after: currentPlanningMonth) }
    var availableMonths: [SelectedStatementMonth] {
        let current = currentPlanningMonth
        return Set([current, Self.nextMonth(after: current), month] + Array(monthDrafts.keys) + fundingPlanStore.plans.filter { $0.workspaceID == workspaceID }.map(\.month)).sorted()
    }
    private static func nextMonth(after month: SelectedStatementMonth) -> SelectedStatementMonth {
        try! SelectedStatementMonth(year: month.month == 12 ? month.year + 1 : month.year, month: month.month == 12 ? 1 : month.month + 1)
    }

    func switchMonth(to target: SelectedStatementMonth) {
        guard target != month, Self.planningMonths.contains(target) || fundingPlanStore.plan(for: target, workspaceID: workspaceID) != nil,
              saveState != .saving, saveState != .committedNeedsRefresh else { return }
        hasOpenedPlanner = true
        monthDrafts[month] = MonthDraftState(plan: plan, raw: rawText, errors: fieldErrors, untouched: untouchedZeroFields,
            unavailable: unavailableCurrentBalanceAccountIDs, generation: baseGeneration, canonical: baseCanonical,
            baseRaw: baseRawText, basePlan: baseDraftPlan, dirty: isDirty, saveState: saveState, error: errorMessage, committed: committedCandidate,
            preReductionBasis: preReductionBasis)
        month = target
        if let state = monthDrafts.removeValue(forKey: target) {
            plan = state.plan; rawText = state.raw; fieldErrors = state.errors; untouchedZeroFields = state.untouched
            unavailableCurrentBalanceAccountIDs = state.unavailable; baseGeneration = state.generation; baseCanonical = state.canonical
            baseRawText = state.baseRaw; baseDraftPlan = state.basePlan; isDirty = state.dirty; saveState = state.saveState
            errorMessage = state.error; committedCandidate = state.committed
            preReductionBasis = state.preReductionBasis
            canonicalDidPublish(); recalculate()
        } else {
            rebaseFromPublishedPlan(generation: provider().generationToken)
        }
        refreshCapturedAccountBalances()
    }

    /// One explicit draft adoption; the saved legacy record remains unchanged until Save.
    func adoptBudgetPlanning() {
        guard canEdit, plan.calculationVersion == .legacy else { return }
        let oldDeduction = plan.expectedDeductions
        guard oldDeduction.amount >= 0 else { errorMessage = "Review the prior deduction before adopting Budget Planning."; return }
        plan.calculationVersion = .budgetV1; plan.keepInCBQ = Self.zeroQAR
        if oldDeduction.amount > 0 {
            plan.deductions = [.init(id: UUID().uuidString, label: "Prior deduction total · unitemized", money: oldDeduction, recurs: false)]
        }
        plan.expectedDeductions = Self.zeroQAR; plan.plannedInvestment = Self.zeroQAR
        plan.referenceMode = plan.planningFX == nil ? .alDar : .manual
        plan.alDarReference = nil
        syncDraft(); markEdited(); recalculate()
    }

    func receiveSharedReference(_ reference: AlDarUnitReference?) {
        sharedINRReference = reference
        recalculate()
    }

    func useSharedAlDar() {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return }
        plan.referenceMode = .alDar; plan.planningFX = nil; plan.alDarReference = nil
        plan.effectiveAlDarReference = sharedINRReference.flatMap { try? $0.planningQuote() }
        rawText["fx.rate"] = ""; rawText["fx.date"] = ""; fieldErrors["fx.rate"] = nil; fieldErrors["fx.date"] = nil
        markEdited(); recalculate()
    }

    func addDeduction() {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return }
        let row = FundingPlanDeduction(id: UUID().uuidString, label: "", money: Self.zeroQAR, recurs: true)
        plan.deductions.append(row); rawText["deduction.label.\(row.id)"] = ""; rawText["deduction.amount.\(row.id)"] = "0"
        untouchedZeroFields.insert("deduction.amount.\(row.id)"); fieldErrors["deduction.label.\(row.id)"] = "Enter a name"
        markEdited(); recalculate()
    }

    func editDeduction(id: String, label: String? = nil, amount: String? = nil, recurs: Bool? = nil) {
        guard canEdit, let index = plan.deductions.firstIndex(where: { $0.id == id }) else { return }
        if let label {
            rawText["deduction.label.\(id)"] = label
            fieldErrors["deduction.label.\(id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a name of 1–240 characters" : nil
            plan.deductions[index].label = label
        }
        if let amount {
            let key = "deduction.amount.\(id)"; rawText[key] = amount; untouchedZeroFields.remove(key)
            if let money = try? PlannerInputCodec.money(amount, currency: "QAR", locale: locale), money.amount >= 0 {
                plan.deductions[index].money = money; fieldErrors[key] = nil
            } else { fieldErrors[key] = "Enter a deduction of zero or greater" }
        }
        if let recurs { plan.deductions[index].recurs = recurs }
        markEdited(); recalculate()
    }

    func removeDeduction(id: String) {
        guard canEdit else { return }
        plan.deductions.removeAll { $0.id == id }
        for key in ["deduction.label.\(id)", "deduction.amount.\(id)"] { rawText[key] = nil; fieldErrors[key] = nil; untouchedZeroFields.remove(key) }
        markEdited(); recalculate()
    }

    func setCommitmentDetails(region: String, id: String, recurs: Bool? = nil, temporary: Bool? = nil, remark: String? = nil) {
        guard canEdit else { return }
        var rows = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        if let recurs { rows[index].recurs = recurs; if !recurs { rows[index].temporaryCarryBasis = nil; preReductionBasis[id] = nil } }
        if let temporary {
            if temporary && rows[index].recurs && rows[index].temporaryCarryBasis == nil {
                rows[index].temporaryCarryBasis = preReductionBasis.removeValue(forKey: id) ?? rows[index].money
            }
            if !temporary {
                if let basis = rows[index].temporaryCarryBasis {
                    rows[index].money = basis
                    rawText["amount.\(id)"] = (try? basis.canonicalDecimalString()).map(localized) ?? ""
                    fieldErrors["amount.\(id)"] = nil
                }
                rows[index].temporaryCarryBasis = nil
            }
        }
        if let remark { rows[index].remark = String(remark.prefix(240)) }
        if region == "qatar" { plan.qatarCommitments = rows } else { plan.indiaCommitments = rows }
        markEdited(); recalculate()
    }

    private static func seed(_ previous: FundingPlan, for month: SelectedStatementMonth) -> FundingPlan {
        var result = emptyPlan(month: month, workspaceID: previous.workspaceID)
        let source = previous.id
        result.rolloverSourcePlanID = source
        result.expectedFixedEarnings = previous.expectedFixedEarnings; result.expectedFixedProvenance = .carried(sourcePlanID: source)
        result.expectedVariableEarnings = previous.expectedVariableEarnings; result.expectedVariableProvenance = .carried(sourcePlanID: source)
        result.configuredTransferFee = previous.configuredTransferFee; result.configuredTransferFeeProvenance = .carried(sourcePlanID: source)
        result.keepInCBQ = previous.keepInCBQ ?? zeroQAR
        result.balances = previous.balances.map { .init(id: UUID().uuidString, accountID: $0.accountID, nativeCurrency: $0.nativeCurrency, included: $0.included, money: $0.money, provenance: .carried(sourcePlanID: source)) }
        func rows(_ values: [FundingPlanCommitment]) -> [FundingPlanCommitment] {
            values.filter(\.recurs).map { .init(id: UUID().uuidString, label: $0.label, money: $0.temporaryCarryBasis ?? $0.money,
                included: $0.included, fundingAccountID: $0.fundingAccountID, provenance: .carried(sourcePlanID: source),
                carriedSourceRowID: $0.id, remark: $0.remark,
                dueDate: $0.dueDate) }
        }
        result.qatarCommitments = rows(previous.qatarCommitments); result.indiaCommitments = rows(previous.indiaCommitments)
        result.deductions = previous.deductions.filter(\.recurs).map { .init(id: UUID().uuidString, label: $0.label, money: $0.money, recurs: true, carriedSourceRowID: $0.id) }
        if previous.calculationVersion == .legacy, previous.expectedDeductions.amount > 0 {
            // Preserve the known prior total without inventing component names
            // or declaring that every item inside it recurs indefinitely.
            result.deductions = [.init(id: UUID().uuidString, label: "Prior deduction total · unitemized", money: previous.expectedDeductions, recurs: false)]
        }
        // No previous manual override or applied external reference is current authority.
        return result
    }

    var canEdit: Bool {
        Self.planningMonths.contains(month) && ![.saving, .failed, .committedNeedsRefresh, .committedToPreviousProvider, .providerChanged, .canonicalChanged].contains(saveState) &&
        (!requiresApplicationAvailability || ApplicationAvailability.shared.permitsMutation)
    }
    var canSave: Bool {
        canEdit && provider().persistenceState.isUsable && provider().generationToken == baseGeneration && fundingPlanStore.generation == baseGeneration &&
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
    var hasUnsavedDrafts: Bool { isDirty || monthDrafts.values.contains(where: { $0.dirty }) }
    var canRollover: Bool { fundingPlanStore.plan(for: month, workspaceID: workspaceID) == nil && fundingPlanStore.plans.contains { $0.workspaceID == workspaceID && $0.month < month } }


    @Published private(set) var month: SelectedStatementMonth
    private let workspaceID: String
    private let provider: () -> DatabaseProvider
    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let salaryStore: SalaryStore
    private let fundingPlanStore: FundingPlanStore

    init(
        month: SelectedStatementMonth? = nil,
        workspaceID: String = "default-workspace",
        provider: (() -> DatabaseProvider)? = nil,
        accountStore: AccountStore? = nil,
        transactionStore: TransactionStore? = nil,
        salaryStore: SalaryStore? = nil,
        fundingPlanStore: FundingPlanStore? = nil,
        locale: Locale = .current,
        now: @escaping () -> Date = { Date() },
        refresh: ((DatabaseProvider) throws -> Void)? = nil
    ) {
        let current = Self.currentMonth(now: now())
        let resolvedMonth = month ?? current
        self.now = now
        self.currentPlanningMonth = current
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
        self.transactionStore = transactionStore ?? .shared
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
        // Reuse the accepted Dashboard delivery boundary. Only the available
        // month controls advance; an active draft never switches automatically.
        self.calendarSubscription = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshCalendarMonth() }
    }

    /// Opening Dashboard must not create an invisible unsaved planning draft.
    func plannerOpened() {
        refreshCalendarMonth()
        hasOpenedPlanner = true
        canonicalDidPublish()
        if baseCanonical == nil && !isDirty && canRollover { rolloverFromPreviousPlan() }
        refreshCapturedAccountBalances()
    }

    private func refreshCalendarMonth() {
        let current = Self.currentMonth(now: now())
        if current != currentPlanningMonth { currentPlanningMonth = current }
    }

    var statements: [SalaryStatement] { salaryStore.statements }
    var planMonthTitle: String { Self.monthTitle(plan.month) }

    static func monthTitle(_ month: SelectedStatementMonth) -> String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(names[month.month - 1]) \(month.year)"
    }
    var eligibleAccounts: [Account] { plannerAccounts(type: .bank) }
    var eligibleCommitmentAccounts: [Account] { plannerAccounts(type: .creditCard) }

    func retainedCommitmentAccountLabel(id: String) -> String {
        guard let account = accountStore.accounts.first(where: { $0.repositoryAccountId == id }) else { return "Saved account unavailable" }
        let role = account.type == .bank ? "Saved funding bank" : "Saved account"
        return "\(role) · \(account.nickname ?? account.name)"
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
        case .reserve: money = plan.keepInCBQ ?? Self.zeroQAR
        }
        return (try? money.canonicalDecimalString()) ?? ""
    }

    /// Blank presentation for untouched defaults never replaces valid zero
    /// draft text or hides a zero entered, saved, captured or rolled forward.
    func amountInputText(_ key: String) -> String {
        let text = rawText[key] ?? ""
        return untouchedZeroFields.contains(key) && text == "0" ? "" : text
    }

    @discardableResult
    func updateMoney(_ field: MoneyField, text: String) -> Bool {
        guard canEdit else { return false }
        guard plan.calculationVersion == .legacy || ![MoneyField.deductions, .investment].contains(field) else { return false }
        untouchedZeroFields.remove(field.rawValue)
        rawText[field.rawValue] = text
        markEdited()
        guard let value = validatedMoney(field, text: text) else { return false }
        switch field {
        case .fixed: plan.expectedFixedEarnings = value; plan.expectedFixedProvenance = .manual
        case .variable: plan.expectedVariableEarnings = value; plan.expectedVariableProvenance = .manual
        case .deductions: plan.expectedDeductions = value; plan.expectedDeductionsProvenance = .manual
        case .fee: plan.configuredTransferFee = value; plan.configuredTransferFeeProvenance = .manual
        case .investment: plan.plannedInvestment = value; plan.plannedInvestmentProvenance = .manual
        case .reserve: plan.keepInCBQ = value
        }
        recalculate()
        return true
    }

    func setFX(rateText: String, dateText: String) {
        guard canEdit else { return }
        plan.referenceMode = .manual; plan.effectiveAlDarReference = nil
        plan.alDarReference = nil
        plan.planningFX = nil
        rawText["fx.rate"] = rateText; rawText["fx.date"] = dateText
        markEdited()
        fieldErrors["fx.rate"] = nil; fieldErrors["fx.date"] = nil
        if rateText.isEmpty && dateText.isEmpty {
            plan.planningFX = nil
            if plan.calculationVersion == .budgetV1 { fieldErrors["fx.rate"] = "Enter a positive rate or choose Use Al Dar" }
            recalculate(); return
        }
        let rate = try? PlannerInputCodec.rate(rateText, locale: locale)
        let date = try? StatementDate(canonical: dateText)
        if rate == nil { fieldErrors["fx.rate"] = "Enter a complete positive INR-per-QAR rate" }
        if date == nil { fieldErrors["fx.date"] = "Enter the observation date as YYYY-MM-DD" }
        guard let rate, let date, let fx = try? FundingPlanFX(inrPerQAR: rate, observationDate: date) else { recalculate(); return }
        plan.planningFX = fx
        recalculate()
    }

    var manualFXObservationDateTitle: String {
        let text = rawText["fx.date"] ?? ""
        return (try? StatementDate(canonical: text))?.presentation ?? (text.isEmpty ? "Observed date" : text)
    }

    /// Foundation.Date is only the native picker carrier for this user-entered
    /// observation day. Imported financial dates never enter this adapter.
    func manualFXPickerDate(now: Date = Date(), timeZone: TimeZone = .current) -> Date {
        guard let day = try? StatementDate(canonical: rawText["fx.date"] ?? "") else { return now }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? now
    }

    func setManualFXObservationDate(_ selection: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: selection)
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let date = try? StatementDate(year: year, month: month, day: day) else { return }
        setFX(rateText: rawText["fx.rate"] ?? "", dateText: date.canonical)
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
        guard let money = currentBankBalance(account) else {
            if let id = account.repositoryAccountId { unavailableCurrentBalanceAccountIDs.insert(id) }
            errorMessage = "The current bank balance is unavailable. You can enter a planning balance manually."
            return
        }
        captureAccountBalance(account, money: money, capturedAt: ISO8601DateFormatter().string(from: Date()))
        recalculate()
    }

    /// Opening Salary refreshes captured values in the draft only. Manual and
    /// carried amounts, inclusion choices and invalid in-progress text survive.
    func refreshCapturedAccountBalances() {
        canonicalDidPublish()
        unavailableCurrentBalanceAccountIDs = []
        let active = provider()
        guard canEdit, active.persistenceState.isUsable,
              active.generationToken == baseGeneration,
              fundingPlanStore.generation == baseGeneration else { return }
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        var changed = false
        for account in eligibleAccounts {
            guard let id = account.repositoryAccountId,
                  fieldErrors["balance.\(id)"] == nil else { continue }
            let existing = plan.balances.first { $0.accountID == id }
            if let existing, existing.money != nil {
                guard case .capturedAccountBalance = existing.provenance else { continue }
            }
            guard let money = currentBankBalance(account) else {
                unavailableCurrentBalanceAccountIDs.insert(id)
                continue
            }
            // An unchanged value keeps its truthful earlier capture time and
            // does not create an unsaved change merely from reopening a tab.
            guard existing?.money != money else { continue }
            captureAccountBalance(account, money: money, capturedAt: capturedAt)
            changed = true
        }
        if changed { recalculate() }
    }

    private func currentBankBalance(_ account: Account) -> Money? {
        guard let id = account.repositoryAccountId,
              account.type == .bank else { return nil }
        // Reuse canonical bank source selection; Account's zero fallback is
        // not evidence that an unavailable balance is actually zero.
        return try? RepositoryStoreHydrator.latestRunningBalance(
            from: transactionStore.transactions.filter { $0.repositoryAccountId == id },
            currency: account.nativeCurrency.code
        )
    }

    private func captureAccountBalance(_ account: Account, money: Money, capturedAt: String) {
        guard let id = account.repositoryAccountId else { return }
        unavailableCurrentBalanceAccountIDs.remove(id)
        markEdited()
        rawText["balance.\(id)"] = (try? money.canonicalDecimalString()).map(localized) ?? ""
        fieldErrors["balance.\(id)"] = nil
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = money
            plan.balances[index].provenance = .capturedAccountBalance(capturedAtISO: capturedAt)
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: money, provenance: .capturedAccountBalance(capturedAtISO: capturedAt)))
        }
    }

    func setManualBalance(_ account: Account, text: String) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        unavailableCurrentBalanceAccountIDs.remove(id)
        let key = "balance.\(id)"
        untouchedZeroFields.remove(key)
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
        untouchedZeroFields.insert("amount.\(value.id)")
        if region == "qatar" { plan.qatarCommitments.append(value) }
        else { plan.indiaCommitments.append(value) }
        recalculate()
    }

    func updateCommitment(region: String, id: String, label: String, amountText: String, included: Bool, fundingAccountID: String?, amountWasEdited: Bool = true) {
        guard canEdit else { return }
        if amountWasEdited { untouchedZeroFields.remove("amount.\(id)") }
        let currency = region == "qatar" ? "QAR" : "INR"
        rawText["label.\(id)"] = label; rawText["amount.\(id)"] = amountText
        markEdited()
        fieldErrors["label.\(id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a label of 1–240 characters" : nil
        let money = try? PlannerInputCodec.money(amountText, currency: currency, locale: locale)
        fieldErrors["amount.\(id)"] = money == nil ? "Enter an exact \(currency) amount" : nil
        var values = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = values.firstIndex(where: { $0.id == id }) else { return }
        if plan.calculationVersion == .budgetV1, let money,
           money.amount < 0 || (values[index].temporaryCarryBasis.map { money.amount > $0.amount } ?? false) {
            fieldErrors["amount.\(id)"] = "Enter a nonnegative remaining amount no greater than the recurring estimate"
            recalculate(); return
        }
        let changedValue = values[index].label != label || (money != nil && values[index].money != money)
        if amountWasEdited, let money, plan.calculationVersion == .budgetV1,
           values[index].recurs, values[index].temporaryCarryBasis == nil {
            if money.amount < values[index].money.amount, preReductionBasis[id] == nil {
                preReductionBasis[id] = values[index].money
            } else if let basis = preReductionBasis[id], money.amount >= basis.amount {
                preReductionBasis[id] = nil
            }
        }
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
            fundingAccountID: field == "account" ? (text.isEmpty ? nil : text) : value.fundingAccountID,
            amountWasEdited: field == "amount")
    }

    func removeCommitment(region: String, id: String) {
        guard canEdit else { return }
        preReductionBasis[id] = nil
        markEdited()
        for key in ["label.\(id)", "amount.\(id)"] { rawText[key] = nil; fieldErrors[key] = nil; untouchedZeroFields.remove(key) }
        if region == "qatar" { plan.qatarCommitments.removeAll { $0.id == id } }
        else { plan.indiaCommitments.removeAll { $0.id == id } }
        recalculate()
    }

    func billDatePickerValue(for row: FundingPlanCommitment, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let selected = row.dueDate(in: month) ?? row.dueDate
        return calendar.date(from: DateComponents(year: selected?.year ?? month.year, month: selected?.month ?? month.month, day: selected?.day ?? 1, hour: 12))!
    }

    func setBillDate(region: String, id: String, date: Date?, timeZone: TimeZone = .current) {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return }
        var rows = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        var due: StatementDate?
        if let date {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let selectedMonth = parts.month, let day = parts.day,
                  let valid = try? StatementDate(year: year, month: selectedMonth, day: day) else {
                errorMessage = "Choose a valid bill date."; return
            }
            due = valid
        }
        rows[index].dueDate = due
        if region == "qatar" { plan.qatarCommitments = rows } else { plan.indiaCommitments = rows }
        markEdited(); recalculate()
    }

    func rolloverFromPreviousPlan(discardingDraft: Bool = false) {
        guard canEdit else { return }
        guard !isDirty || discardingDraft else { errorMessage = "Choose whether to discard the unsaved draft before copying the previous plan."; return }
        guard fundingPlanStore.plan(for: month, workspaceID: workspaceID) == nil,
              let previous = fundingPlanStore.plans.filter({ $0.workspaceID == workspaceID && $0.month < month }).max(by: { $0.month < $1.month }) else {
            errorMessage = "No earlier editable plan is available to roll forward, or this month already exists."
            return
        }
        plan = Self.seed(previous, for: month)
        syncDraft()
        markEdited()
        recalculate()
    }

    func save() {
        let lease: DatabaseActivityLease
        do { lease = try DatabaseActivityGate.shared.begin(.repositoryWrite) }
        catch { errorMessage = "Wait for database recovery to finish before saving."; return }
        defer { lease.finish() }
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
        let lease: DatabaseActivityLease
        do { lease = try DatabaseActivityGate.shared.begin(.hydration) }
        catch { errorMessage = "Wait for database recovery to finish before reloading."; return }
        defer { lease.finish() }
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
        preReductionBasis = [:]
        baseGeneration = generation
        baseCanonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID)
        plan = baseCanonical ?? Self.emptyPlan(month: month, workspaceID: workspaceID)
        isDirty = false; saveState = .ready; errorMessage = nil
        syncDraft(); captureDraftBase()
        // Seed a new month before attaching shared FX evidence. The reference
        // itself changes the draft and would otherwise block carry-forward.
        if hasOpenedPlanner, baseCanonical == nil, canRollover {
            rolloverFromPreviousPlan()
        } else {
            recalculate()
        }
    }

    private func canonicalDidPublish() {
        guard !isRebasing && saveState != .saving else { return }
        for key in Array(monthDrafts.keys) {
            guard var state = monthDrafts[key] else { continue }
            let changed = state.generation != provider().generationToken || fundingPlanStore.generation != state.generation
            if changed || fundingPlanStore.plan(for: key, workspaceID: workspaceID) != state.canonical {
                if state.dirty { state.saveState = changed ? .providerChanged : .canonicalChanged; monthDrafts[key] = state }
                else { monthDrafts[key] = nil }
            }
        }
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

    private func captureDraftBase() { baseRawText = rawText; baseDraftPlan = plan; isDirty = false; preReductionBasis = [:] }

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
        untouchedZeroFields = []
        for field in MoneyField.allCases { rawText[field.rawValue] = localized(moneyText(field)) }
        if baseCanonical == nil && plan.rolloverSourcePlanID == nil {
            untouchedZeroFields = Set(MoneyField.allCases.map(\.rawValue).filter { rawText[$0] == "0" })
        }
        rawText["fx.rate"] = plan.planningFX.map { localized(NSDecimalNumber(decimal: $0.inrPerQAR).stringValue) } ?? ""
        rawText["fx.date"] = plan.planningFX?.observationDate.canonical ?? ""
        for balance in plan.balances { rawText["balance.\(balance.accountID)"] = (try? balance.money?.canonicalDecimalString()).map(localized) ?? "" }
        for value in plan.deductions {
            rawText["deduction.label.\(value.id)"] = value.label
            rawText["deduction.amount.\(value.id)"] = (try? value.money.canonicalDecimalString()).map(localized) ?? ""
        }
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
        guard ![MoneyField.fee, .reserve].contains(field) || value.amount >= 0 else {
            fieldErrors[field.rawValue] = field == .fee ? "Transfer fee must be zero or greater" : "Reserve must be zero or greater"
            return nil
        }
        fieldErrors[field.rawValue] = nil
        return value
    }

    private func validateVisibleDraft() {
        for field in visibleMoneyFields {
            _ = validatedMoney(field, text: moneyText(field))
        }
        for row in plan.deductions {
            let label = rawText["deduction.label.\(row.id)"] ?? ""
            fieldErrors["deduction.label.\(row.id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a deduction name" : nil
            let value = try? PlannerInputCodec.money(rawText["deduction.amount.\(row.id)"] ?? "", currency: "QAR", locale: locale)
            fieldErrors["deduction.amount.\(row.id)"] = value.map { $0.amount >= 0 } == true ? nil : "Enter a nonnegative deduction"
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
                let parsed = try? PlannerInputCodec.money(amount, currency: region == "qatar" ? "QAR" : "INR", locale: locale)
                let valid = parsed.map { money in
                    plan.calculationVersion == .legacy || (money.amount >= 0 && (value.temporaryCarryBasis.map { money.amount <= $0.amount } ?? true))
                } ?? false
                fieldErrors["amount.\(value.id)"] = valid ? nil : "Enter a nonnegative amount within the remaining-payment basis"
            }
        }
    }

    func provenanceText(_ value: FundingPlanValueProvenance) -> String {
        switch value {
        case .manual: return "Your estimate"
        case .capturedAccountBalance(let time): return "Captured from account · \(time)"
        case .carried(let id): return fundingPlanStore.plans.first(where: { $0.id == id }).map { "Copied from \(Self.monthTitle($0.month))" } ?? "Copied from an earlier plan"
        }
    }

    func dismissError() { errorMessage = nil }

    private func recalculate() {
        if hasOpenedPlanner, canEdit, fieldErrors.isEmpty, plan.calculationVersion == .budgetV1, plan.referenceMode == .alDar,
           provider().generationToken == baseGeneration, fundingPlanStore.generation == baseGeneration {
            plan.effectiveAlDarReference = sharedINRReference.flatMap { try? $0.planningQuote() }
        }
        calculation = FundingPlanCalculator.calculate(plan)
        if saveState != .committedNeedsRefresh { isDirty = rawText != baseRawText || plan != baseDraftPlan }
    }

    private static func currentMonth(now: Date = Date()) -> SelectedStatementMonth {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: now)
        return try! SelectedStatementMonth(year: parts.year!, month: parts.month!)
    }

    private static func emptyPlan(month: SelectedStatementMonth, workspaceID: String) -> FundingPlan {
        let zero = try! Money(canonicalDecimal: "0.00", currency: "QAR")
        let fee = zero
        return FundingPlan(id: UUID().uuidString, workspaceID: workspaceID, month: month, rolloverSourcePlanID: nil,
                           expectedFixedEarnings: zero, expectedFixedProvenance: .manual,
                           expectedVariableEarnings: zero, expectedVariableProvenance: .manual,
                           expectedDeductions: zero, expectedDeductionsProvenance: .manual,
                           balances: [], qatarCommitments: [], indiaCommitments: [],
                           configuredTransferFee: fee, configuredTransferFeeProvenance: .manual,
                           planningFX: nil, plannedInvestment: zero, plannedInvestmentProvenance: .manual,
                           updatedAtISO: ISO8601DateFormatter().string(from: Date()),
                           calculationVersion: .budgetV1, keepInCBQ: zero)
    }

    private func plannerAccounts(type: AccountType) -> [Account] {
        // Native currency and typed role own eligibility; names and institution do not establish a subtype.
        accountStore.accounts.filter {
            guard let repositoryID = $0.repositoryAccountId, !repositoryID.isEmpty else { return false }
            return $0.status == .active && $0.type == type && ["QAR", "INR"].contains($0.nativeCurrency.code)
        }.sorted { ($0.nativeCurrency.code, $0.name, $0.repositoryAccountId ?? "") < ($1.nativeCurrency.code, $1.name, $1.repositoryAccountId ?? "") }
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
                                                provenanceCode: p.code, carriedSourcePlanId: p.carried,
                                                recurs: value.recurs, temporaryCarryBasisMinor: try value.temporaryCarryBasis?.minorUnits(),
                                                temporaryCarryBasisDecimal: try value.temporaryCarryBasis?.canonicalDecimalString(),
                                                carriedSourceRowId: value.carriedSourceRowID, remark: value.remark, dueDateISO: value.dueDate?.canonical)
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
            commitments: try commitmentDTOs(plan.qatarCommitments, region: "qatar") + commitmentDTOs(plan.indiaCommitments, region: "india"),
            alDarReference: try plan.alDarReference.map { try FundingPlanAlDarReferenceDTO(planID: plan.id, evidence: $0) },
            calculationVersion: plan.calculationVersion.rawValue,
            keepInCBQMinor: try plan.keepInCBQ?.minorUnits(), keepInCBQDecimal: try plan.keepInCBQ?.canonicalDecimalString(),
            referenceMode: plan.calculationVersion == .budgetV1 ? plan.referenceMode.rawValue : nil,
            deductions: try plan.deductions.enumerated().map { index, row in
                FundingPlanDeductionDTO(id: row.id, planId: plan.id, sourceOrdinal: index + 1, label: row.label,
                    amountMinor: try row.money.minorUnits(), amountDecimal: try row.money.canonicalDecimalString(),
                    recurs: row.recurs, carriedSourceRowId: row.carriedSourceRowID)
            },
            effectiveReference: try plan.effectiveAlDarReference.map {
                guard $0.submittedQAR.currency.code == "QAR", $0.submittedQAR.amount == 1 else { throw AlDarReferenceError.invalidBinding }
                return FundingPlanEffectiveReferenceDTO(planId: plan.id, rawINR: $0.returnedINR.rawToken, fetchedAtISO: $0.fetchedAtISO)
            }
        )
    }
}
