import AppKit
import Combine
import Foundation

@MainActor
final class SalaryWorkspaceViewModel: ObservableObject {
    private static let openWorkspaces = NSHashTable<SalaryWorkspaceViewModel>.weakObjects()
    let planningAnalysis = PlanningAnalysisModel()

    enum MoneyField: String, CaseIterable { case fixed, variable, deductions, fee, investment, reserve }
    struct InsightSelection {
        var section = "Cash runway"
        var accountID = ""
        var currency = "INR"
        var scenario = PlanningScenario()
        var scenarioIncome = ""
        var scenarioCost = ""
        var scenarioContribution = ""
    }
    @Published var destinationSection = "This Month"
    @Published var insightSelection = InsightSelection()

    @Published private(set) var plan: FundingPlan
    @Published private(set) var calculation: FundingPlanCalculation
    @Published private(set) var errorMessage: String?
    @Published private(set) var rawText: [String: String] = [:]
    @Published private(set) var fieldErrors: [String: String] = [:]
    @Published private(set) var unavailableCurrentBalanceAccountIDs: Set<String> = []
    @Published private var untouchedZeroFields: Set<String> = []
    @Published private(set) var isDirty = false
    @Published private(set) var saveState: SaveState = .ready
    enum SaveState: Equatable { case ready, saving, saved, failed, retentionFailed, committedNeedsRefresh, committedToPreviousProvider, providerChanged, canonicalChanged }
    private let locale: Locale
    private var baseGeneration: ProviderGenerationToken
    private var baseCanonical: FundingPlan?
    private var isRebasing = false
    private var committedCandidate: FundingPlan?
    private var baseRawText: [String: String] = [:]
    private var baseDraftPlan: FundingPlan?
    private var subscription: AnyCancellable?
    private var calendarSubscription: AnyCancellable?
    private var planningPreferenceSubscription: AnyCancellable?
    private var accountScopeSubscription: AnyCancellable?
    /// Explicit history selection is a view filter, never a change to saved
    /// account lifecycle or to the retained monthly worksheet.
    @Published private(set) var selectedHistoryAccountIDs: Set<String> = []
    private var retentionTask: Task<Void, Never>?
    private var commitTask: Task<Void, Never>?
    private var recurringTask: Task<Void, Never>?
    private var retainedScratchpad: MonthlyPlanScratchpad?
    private var excludedRecurringOccurrenceIDs: Set<String> = []
    @Published private(set) var retentionPending = false
    private let now: () -> Date
    private let refresh: (DatabaseProvider) throws -> Void
    private let requiresApplicationAvailability: Bool
    private var sharedINRReference: AlDarUnitReference?
    private var hasOpenedPlanner = false
    /// Retained value before a reduction. The one-month exception can be
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
        let excludedRecurringOccurrenceIDs: Set<String>
        let retainedScratchpad: MonthlyPlanScratchpad?
        let retentionPending: Bool
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
        flushPendingEntries()
        guard saveState != .saving && saveState != .committedNeedsRefresh && !retentionPending else { return }
        hasOpenedPlanner = true
        recurringTask?.cancel()
        monthDrafts[month] = MonthDraftState(plan: plan, raw: rawText, errors: fieldErrors, untouched: untouchedZeroFields,
            unavailable: unavailableCurrentBalanceAccountIDs, generation: baseGeneration, canonical: baseCanonical,
            baseRaw: baseRawText, basePlan: baseDraftPlan, dirty: isDirty, saveState: saveState, error: errorMessage, committed: committedCandidate,
            preReductionBasis: preReductionBasis, excludedRecurringOccurrenceIDs: excludedRecurringOccurrenceIDs,
            retainedScratchpad: retainedScratchpad, retentionPending: retentionPending)
        month = target
        selectedHistoryAccountIDs = []
        selectionDefaults?.set(target.canonical, forKey: Self.selectedMonthKey(workspaceID: workspaceID))
        if let state = monthDrafts.removeValue(forKey: target) {
            plan = state.plan; rawText = state.raw; fieldErrors = state.errors; untouchedZeroFields = state.untouched
            unavailableCurrentBalanceAccountIDs = state.unavailable; baseGeneration = state.generation; baseCanonical = state.canonical
            baseRawText = state.baseRaw; baseDraftPlan = state.basePlan; isDirty = state.dirty; saveState = state.saveState
            errorMessage = state.error; committedCandidate = state.committed
            preReductionBasis = state.preReductionBasis
            excludedRecurringOccurrenceIDs = state.excludedRecurringOccurrenceIDs
            retainedScratchpad = state.retainedScratchpad; retentionPending = state.retentionPending
            canonicalDidPublish(); recalculate()
        } else {
            rebaseFromPublishedPlan(generation: provider().generationToken)
        }
        refreshCapturedAccountBalances()
        scheduleRecurringInclusion()
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
        result.assistance?.salaryCycle = SalaryFundingCycle.expected(month: month, day: previous.assistance?.salaryCycle?.expectedDay ?? 25)
        if let prior = previous.assistance?.salaryCycle,
           String(prior.payday.prefix(7)) == String(result.assistance?.salaryCycle?.previousPayday.prefix(7) ?? "") {
            result.assistance?.salaryCycle?.previousPayday = prior.payday
        }
        let source = previous.id
        result.rolloverSourcePlanID = source
        result.expectedFixedEarnings = previous.expectedFixedEarnings; result.expectedFixedProvenance = .carried(sourcePlanID: source)
        result.expectedVariableEarnings = previous.expectedVariableEarnings; result.expectedVariableProvenance = .carried(sourcePlanID: source)
        result.configuredTransferFee = previous.configuredTransferFee; result.configuredTransferFeeProvenance = .carried(sourcePlanID: source)
        result.keepInCBQ = previous.keepInCBQ ?? zeroQAR
        result.balances = previous.balances.map { .init(id: UUID().uuidString, accountID: $0.accountID, nativeCurrency: $0.nativeCurrency, included: $0.included, money: $0.money, provenance: .carried(sourcePlanID: source), financialBalanceDate: $0.financialBalanceDate) }
        let recurringOwnedRows = Set(previous.assistance?.appliedRecurringIDs.values.map { $0 } ?? [])
        func rows(_ values: [FundingPlanCommitment]) -> [FundingPlanCommitment] {
            values.filter { $0.recurs && !recurringOwnedRows.contains($0.id) }.map { .init(id: UUID().uuidString, label: $0.label, money: $0.temporaryCarryBasis ?? $0.money,
                included: $0.included, fundingAccountID: $0.fundingAccountID, provenance: .carried(sourcePlanID: source),
                carriedSourceRowID: $0.id, remark: $0.remark,
                dueDate: $0.dueDate) }
        }
        result.qatarCommitments = rows(previous.qatarCommitments); result.indiaCommitments = rows(previous.indiaCommitments)
        let carriedDates = Dictionary(uniqueKeysWithValues: (result.qatarCommitments + result.indiaCommitments).compactMap { row in
            result.nextRecurringDate(for: row).map { (row.id, $0.canonical) }
        })
        result.assistance?.carriedBillDates = carriedDates
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
        Self.planningMonths.contains(month) && ![.saving, .failed, .retentionFailed, .committedNeedsRefresh, .committedToPreviousProvider, .providerChanged, .canonicalChanged].contains(saveState) &&
        (!requiresApplicationAvailability || ApplicationAvailability.shared.permitsMutation)
    }
    var canSave: Bool {
        canEdit && provider().persistenceState.isUsable && provider().generationToken == baseGeneration && fundingPlanStore.generation == baseGeneration &&
        (!requiresApplicationAvailability || ApplicationAvailability.shared.permitsMutation) &&
        ![.saving, .failed, .committedNeedsRefresh, .committedToPreviousProvider, .providerChanged, .canonicalChanged].contains(saveState) && hasValidCalculation
    }
    var statusText: String {
        switch saveState {
        case .saving: return "Saving…"
        case .saved: return "Kept automatically"
        case .failed: return "Could not retain changes · reopen to review"
        case .retentionFailed: return "Could not retain entries"
        case .committedNeedsRefresh: return "Saved · reload required"
        case .committedToPreviousProvider: return "Saved to the previous database · reload the current database"
        case .providerChanged: return "Database changed · discard this draft to reload"
        case .canonicalChanged: return "Saved plan changed · discard this draft to reload"
        case .ready:
            if retentionPending { return "Keeping changes…" }
            if !fieldErrors.isEmpty && retainedScratchpad != nil { return "Entries kept · some values incomplete" }
            return retainedScratchpad != nil ? "Kept automatically" : "Changes kept automatically"
        }
    }
    var hasValidCalculation: Bool {
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

    enum RetainedPlanPresentation {
        case canonical
        case retained(MonthlyPlanScratchpad)
        case unavailable(String)
    }

    /// Read-only handoff of successfully retained entries. The Dashboard must
    /// never borrow parsed amounts from an incomplete, live editor draft.
    func retainedPlanPresentation(for month: SelectedStatementMonth, workspaceID: String,
                                  generation: ProviderGenerationToken, canonical: FundingPlan?) -> RetainedPlanPresentation? {
        guard self.month == month, self.workspaceID == workspaceID else { return nil }
        guard baseGeneration == generation else {
            return .unavailable("The monthly plan belongs to a different ledger. Reopen Budget Planning.")
        }
        if retentionPending {
            return .unavailable(saveState == .retentionFailed
                ? "Latest plan changes could not be retained. Open Budget Planning."
                : "Keeping the latest plan changes…")
        }
        guard ![.failed, .committedNeedsRefresh, .committedToPreviousProvider, .providerChanged, .canonicalChanged].contains(saveState) else {
            return .unavailable("The monthly plan needs review. Open Budget Planning.")
        }
        guard let retainedScratchpad else { return .canonical }
        guard retainedScratchpad.canonical == canonical else {
            return .unavailable("The retained entries belong to an earlier plan. Open Budget Planning to review them.")
        }
        return .retained(retainedScratchpad)
    }
    /// Secondary presentation uses the same exact plan-local rate as the worksheet.
    var finalBufferINREstimate: Money? {
        guard let buffer = calculation.finalQARBuffer else { return nil }
        let rate: AlDarReturnedINRDecimal?
        if plan.referenceMode == .alDar {
            rate = plan.effectiveAlDarReference.flatMap { $0.submittedQAR.amount == 1 ? $0.returnedINR : nil }
        } else {
            rate = plan.planningFX.flatMap { try? .planningRate($0.inrPerQAR) }
        }
        guard let rate, let magnitude = try? Money(amount: abs(buffer.amount), currency: "QAR"),
              let converted = try? rate.receiveEstimate(forQAR: magnitude) else { return nil }
        return try? Money(amount: buffer.amount < 0 ? -converted.amount : converted.amount, currency: "INR")
    }
    var hasUnsavedDrafts: Bool {
        retentionPending || [.failed, .retentionFailed, .saving, .committedNeedsRefresh, .committedToPreviousProvider].contains(saveState) ||
            monthDrafts.values.contains { $0.retentionPending }
    }
    var canRollover: Bool { fundingPlanStore.plan(for: month, workspaceID: workspaceID) == nil && fundingPlanStore.plans.contains { $0.workspaceID == workspaceID && $0.month < month } }


    @Published private(set) var month: SelectedStatementMonth
    private let workspaceID: String
    private let selectionDefaults: UserDefaults?

    private static func selectedMonthKey(workspaceID: String) -> String {
        "LedgerForge.planning.selectedMonth.v1.\(workspaceID)"
    }
    private let provider: () -> DatabaseProvider
    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let salaryStore: SalaryStore
    private let fundingPlanStore: FundingPlanStore
    private let intelligenceStore: FinancialIntelligenceStore

    init(
        month: SelectedStatementMonth? = nil,
        workspaceID: String = "default-workspace",
        provider: (() -> DatabaseProvider)? = nil,
        accountStore: AccountStore? = nil,
        transactionStore: TransactionStore? = nil,
        salaryStore: SalaryStore? = nil,
        fundingPlanStore: FundingPlanStore? = nil,
        intelligenceStore: FinancialIntelligenceStore? = nil,
        selectionDefaults: UserDefaults? = nil,
        locale: Locale = .current,
        now: @escaping () -> Date = { Date() },
        refresh: ((DatabaseProvider) throws -> Void)? = nil
    ) {
        let current = Self.currentMonth(now: now())
        let retainedMonth = selectionDefaults?.string(forKey: Self.selectedMonthKey(workspaceID: workspaceID))
            .flatMap { try? SelectedStatementMonth(canonical: $0) }
        let resolvedMonth = month ?? retainedMonth ?? current
        self.now = now
        self.currentPlanningMonth = current
        let resolvedAccountStore = accountStore ?? .shared
        let resolvedSalaryStore = salaryStore ?? .shared
        let resolvedFundingPlanStore = fundingPlanStore ?? .shared
        self.month = resolvedMonth
        self.workspaceID = workspaceID
        self.selectionDefaults = selectionDefaults
        self.provider = provider ?? { DatabaseProvider.shared }
        self.requiresApplicationAvailability = provider == nil && fundingPlanStore == nil
        self.locale = locale
        self.baseGeneration = (provider?() ?? DatabaseProvider.shared).generationToken
        self.refresh = refresh ?? { active in _ = try RepositoryStoreHydrator(databaseProvider: active).hydrateIfNeeded(forceRefresh: true) }
        self.accountStore = resolvedAccountStore
        self.transactionStore = transactionStore ?? .shared
        self.salaryStore = resolvedSalaryStore
        self.fundingPlanStore = resolvedFundingPlanStore
        self.intelligenceStore = intelligenceStore ?? .shared
        let canonicalIsCurrent = resolvedFundingPlanStore.generation == self.baseGeneration
        let initial = (canonicalIsCurrent ? resolvedFundingPlanStore.plan(for: resolvedMonth, workspaceID: workspaceID) : nil) ?? Self.emptyPlan(month: resolvedMonth, workspaceID: workspaceID)
        self.baseCanonical = canonicalIsCurrent ? resolvedFundingPlanStore.plan(for: resolvedMonth, workspaceID: workspaceID) : nil
        self.saveState = canonicalIsCurrent ? .ready : .providerChanged
        self.plan = initial
        let exclusions = (self.intelligenceStore.generation == self.baseGeneration ? self.intelligenceStore.snapshot?.preferences?.excludedPlanningAccountIDs ?? [] : [])
            .union(AccountPresentationScope.historyOnlyIDs(in: resolvedAccountStore.accounts))
        self.calculation = FundingPlanCalculator.calculate(initial, excludingAccounts: exclusions,
            historyOnlyAccountIDs: AccountPresentationScope.historyOnlyIDs(in: resolvedAccountStore.accounts),
            salaryReceipt: PayslipReceiptState.resolve(plan: initial, transactions: self.transactionStore.transactions, excludedAccounts: exclusions))
        syncDraft()
        captureDraftBase()
        restoreRetainedEntries()
        self.subscription = resolvedFundingPlanStore.$plans.sink { [weak self] _ in self?.canonicalDidPublish() }
        self.planningPreferenceSubscription = self.intelligenceStore.$snapshot.dropFirst().sink { [weak self] _ in
            guard let self else { return }
            for id in self.manuallyExcludedPlanningAccountIDs { self.fieldErrors["balance.\(id)"] = nil }
            self.recalculate()
            self.scheduleRecurringInclusion()
        }
        self.accountScopeSubscription = resolvedAccountStore.$accounts.dropFirst()
            .receive(on: RunLoop.main).sink { [weak self] _ in
                guard let self else { return }
                self.selectedHistoryAccountIDs.formIntersection(AccountPresentationScope.historyOnlyIDs(in: self.accountStore.accounts))
                self.recalculate()
            }
        Self.openWorkspaces.add(self)
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
        scheduleRecurringInclusion()
        if isDirty { scheduleRetention() }
    }

    private func refreshCalendarMonth() {
        let current = Self.currentMonth(now: now())
        if current != currentPlanningMonth { currentPlanningMonth = current }
    }

    var statements: [SalaryStatement] { salaryStore.statements }
    /// Discovery only. Repeated hydration offers the same source once, and
    /// neither opens another month nor changes a saved or unsaved draft.
    var payslipProposals: [SalaryStatement] {
        guard fundingPlanStore.generation == baseGeneration,
              intelligenceStore.generation == baseGeneration,
              intelligenceStore.snapshot?.preferences?.salaryAssistanceEnabled == true else { return [] }
        let linked = Set(([plan] + fundingPlanStore.plans + monthDrafts.values.map(\.plan))
            .compactMap { $0.assistance?.payslipFunding?.statementID })
        let regular = statements.filter {
            $0.workspaceID == workspaceID && $0.evidence.kind == .regularSalary &&
                $0.evidence.financialPeriod == currentPlanningMonth
        }
        // Two different regular slips for one pay period require source review.
        return regular.count == 1 ? regular.filter { !linked.contains($0.id) } : []
    }
    var payslipReceiptState: PayslipReceiptState? {
        guard fundingPlanStore.generation == baseGeneration, intelligenceStore.generation == baseGeneration else {
            return plan.assistance?.payslipFunding == nil ? nil : .needsReview
        }
        return PayslipReceiptState.resolve(plan: plan, transactions: transactionStore.transactions, excludedAccounts: excludedPlanningAccountIDs)
    }
    var canAcknowledgePayslipBalance: Bool {
        guard canEdit, let link = plan.assistance?.payslipFunding,
              let balance = plan.balances.first(where: { $0.accountID == link.accountID && $0.included }),
              balance.money != nil, let date = balance.financialBalanceDate,
              let payday = plan.assistance?.salaryCycle?.recurringStart,
              date >= payday, !excludedPlanningAccountIDs.contains(link.accountID) else { return false }
        if case .bankCredit(_, let creditDate, _) = payslipReceiptState, date < creditDate { return false }
        if case .capturedAccountBalance = balance.provenance { return true }
        return false
    }
    var planMonthTitle: String { Self.monthTitle(plan.month) }

    static func monthTitle(_ month: SelectedStatementMonth) -> String {
        AppDateDisplay.month(month.canonical)
    }
    var eligibleAccounts: [Account] { plannerAccounts(type: .bank) }
    var historicalPlanningAccounts: [Account] {
        accountStore.accounts.filter {
            $0.isHistoryOnly && $0.type == .bank && ["QAR", "INR"].contains($0.currencyCode)
                && $0.repositoryAccountId.map { !manuallyExcludedPlanningAccountIDs.contains($0) } == true
        }.sorted { $0.preferredDisplayName.localizedStandardCompare($1.preferredDisplayName) == .orderedAscending }
    }
    func isAccountIncluded(_ account: Account) -> Bool {
        guard let id = account.repositoryAccountId, !excludedPlanningAccountIDs.contains(id) else { return false }
        return plan.balances.contains { $0.accountID == id && $0.included }
    }
    func retainedBalanceAccount(id: String) -> Account? {
        guard plan.balances.contains(where: { $0.accountID == id }) else { return nil }
        return accountStore.accounts.first { $0.repositoryAccountId == id }
    }
    var eligibleCommitmentAccounts: [Account] { plannerAccounts(type: .creditCard) }
    var availablePlanningAccounts: [Account] {
        accountStore.accounts.filter { $0.status == .active && [.bank, .creditCard].contains($0.type) && $0.repositoryAccountId != nil }
            .sorted { ($0.nativeCurrency.code, $0.preferredDisplayName, $0.repositoryAccountId ?? "") < ($1.nativeCurrency.code, $1.preferredDisplayName, $1.repositoryAccountId ?? "") }
    }
    var excludedPlanningAccountIDs: Set<String> {
        manuallyExcludedPlanningAccountIDs.union(excludedHistoryAccountIDs)
    }
    var excludedHistoryAccountIDs: Set<String> {
        AccountPresentationScope.historyOnlyIDs(in: accountStore.accounts).subtracting(selectedHistoryAccountIDs)
    }
    private var manuallyExcludedPlanningAccountIDs: Set<String> {
        guard intelligenceStore.generation == baseGeneration else { return [] }
        return intelligenceStore.snapshot?.preferences?.excludedPlanningAccountIDs ?? []
    }

    func retainedCommitmentAccountLabel(id: String) -> String {
        accountStore.accounts.first(where: { $0.repositoryAccountId == id })?.preferredDisplayName ?? "Saved account unavailable"
    }
    func retainedCommitmentAccountContext(id: String) -> String {
        guard let account = accountStore.accounts.first(where: { $0.repositoryAccountId == id }) else { return "This saved account is unavailable." }
        if excludedPlanningAccountIDs.contains(id) { return account.selectionContext + " · Removed from planning; add back or choose another account" }
        let role = account.type == .bank ? "Saved funding bank" : "Saved account"
        return account.selectionContext + " · " + role
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

    var historyScopeAccounts: [Account] {
        accountStore.accounts.filter(\.isHistoryOnly).sorted { $0.preferredDisplayName.localizedStandardCompare($1.preferredDisplayName) == .orderedAscending }
    }
    func setHistoryAccountSelected(_ accountID: String, selected: Bool) {
        guard historyScopeAccounts.contains(where: { $0.repositoryAccountId == accountID }) else { return }
        if selected { selectedHistoryAccountIDs.insert(accountID) } else { selectedHistoryAccountIDs.remove(accountID) }
        recalculate()
    }
    func selectCurrentAccountScope() { selectedHistoryAccountIDs = []; recalculate() }

    func setAccountIncluded(_ account: Account, included: Bool) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        if account.isHistoryOnly {
            if included { selectedHistoryAccountIDs.insert(id) }
            else { selectedHistoryAccountIDs.remove(id) }
        }
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
        guard let balance = currentBankBalance(account) else {
            if let id = account.repositoryAccountId { unavailableCurrentBalanceAccountIDs.insert(id) }
            errorMessage = "The current bank balance is unavailable. You can enter a planning balance manually."
            return
        }
        captureAccountBalance(account, money: balance.money, financialDate: balance.date, capturedAt: ISO8601DateFormatter().string(from: Date()))
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
            guard let balance = currentBankBalance(account) else {
                unavailableCurrentBalanceAccountIDs.insert(id)
                continue
            }
            // An unchanged value keeps its truthful earlier capture time and
            // does not create an unsaved change merely from reopening a tab.
            guard existing?.money != balance.money else { continue }
            // Automatic draft refresh is not the owner's explicit date capture.
            captureAccountBalance(account, money: balance.money, financialDate: nil, capturedAt: capturedAt)
            changed = true
        }
        if changed { recalculate() }
    }

    private func currentBankBalance(_ account: Account) -> (money: Money, date: StatementDate)? {
        guard let id = account.repositoryAccountId,
              account.type == .bank,
              let dateISO = account.currentBalanceAsOfISO,
              let date = try? StatementDate(canonical: String(dateISO.prefix(10))),
              account.currentBalanceMoney.currency == account.nativeCurrency else { return nil }
        let applied = Set(plan.assistance?.appliedSalaryIDs ?? [])
        if !applied.isEmpty {
            let salaries = transactionStore.transactions.filter { $0.repositoryTransactionId.map(applied.contains) == true && $0.repositoryAccountId == id }
            guard salaries.allSatisfy({ salary in
                guard let date = salary.statementDate else { return false }
                return account.currentBalanceAsOfISO.map { String($0.prefix(10)) >= date.canonical } == true
            }) else { return nil }
        }
        // Canonical hydration owns this exact amount/date pair, including
        // statement closing controls. An undated zero fallback is unavailable.
        return (account.currentBalanceMoney, date)
    }

    private func captureAccountBalance(_ account: Account, money: Money, financialDate: StatementDate?, capturedAt: String) {
        guard let id = account.repositoryAccountId else { return }
        unavailableCurrentBalanceAccountIDs.remove(id)
        markEdited()
        rawText["balance.\(id)"] = (try? money.canonicalDecimalString()).map(localized) ?? ""
        fieldErrors["balance.\(id)"] = nil
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = money
            plan.balances[index].provenance = .capturedAccountBalance(capturedAtISO: capturedAt)
            plan.balances[index].financialBalanceDate = financialDate
        } else {
            plan.balances.append(FundingPlanBalance(id: UUID().uuidString, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: money, provenance: .capturedAccountBalance(capturedAtISO: capturedAt), financialBalanceDate: financialDate))
        }
    }

    func setManualBalance(_ account: Account, text: String) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        guard !account.isHistoryOnly || selectedHistoryAccountIDs.contains(id) else { return }
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
            plan.balances[index].financialBalanceDate = nil
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
        if fieldErrors["label.\(id)"] == nil { values[index].label = label }
        if let money { values[index].money = money }
        values[index].included = included
        values[index].fundingAccountID = fundingAccountID
        if changedValue { values[index].provenance = .manual }
        if region == "qatar" { plan.qatarCommitments = values } else { plan.indiaCommitments = values }
        recalculate()
    }

    func isConfirmedRecurringRow(_ id: String) -> Bool {
        plan.assistance?.appliedRecurringIDs.values.contains(id) == true
    }

    func editCommitment(region: String, id: String, field: String, text: String) {
        guard field != "account" || !isConfirmedRecurringRow(id) else { return }
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
        for occurrenceID in plan.assistance?.appliedRecurringIDs.filter({ $0.value == id }).map(\.key) ?? [] {
            excludedRecurringOccurrenceIDs.insert(occurrenceID)
            plan.assistance?.appliedRecurringIDs[occurrenceID] = nil
            plan.assistance?.appliedRecurringPaid?[occurrenceID] = nil
        }
        plan.assistance?.billFundingAccounts?[id] = nil
        plan.assistance?.carriedBillDates?[id] = nil
        for index in plan.assistance?.datedAdjustments.indices ?? 0..<0 {
            if plan.assistance?.datedAdjustments[index].replacesCommitmentID == id { plan.assistance?.datedAdjustments[index].replacesCommitmentID = nil }
        }
        recalculate()
    }

    func billDatePickerValue(for row: FundingPlanCommitment, timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let selected = plan.dueDate(for: row)
        return calendar.date(from: DateComponents(year: selected?.year ?? month.year, month: selected?.month ?? month.month, day: selected?.day ?? 1, hour: 12))!
    }

    func billDateRange(for id: String, timeZone: TimeZone = .current) -> ClosedRange<Date>? {
        guard isConfirmedRecurringRow(id) else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let start = plan.recurringStart, end = plan.recurringEnd
        guard let lower = calendar.date(from: DateComponents(year: start.year, month: start.month, day: start.day)),
              let upper = calendar.date(from: DateComponents(year: end.year, month: end.month, day: end.day, hour: 23, minute: 59, second: 59)) else { return nil }
        return lower...upper
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
        if isConfirmedRecurringRow(id) {
            guard let due, due >= plan.recurringStart, due <= plan.recurringEnd else {
                errorMessage = "Choose a recurring payment date within \(plan.recurringStart.presentation)–\(plan.recurringEnd.presentation)."
                return
            }
        }
        rows[index].dueDate = due
        plan.assistance?.carriedBillDates?[id] = nil
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
        retentionTask?.cancel(); retentionTask = nil
        commitTask?.cancel(); commitTask = nil
        let lease: DatabaseActivityLease
        do { lease = try DatabaseActivityGate.shared.begin(.repositoryWrite) }
        catch { errorMessage = "Wait for database recovery to finish before saving."; return }
        defer { lease.finish() }
        canonicalDidPublish()
        guard canSave else { errorMessage = hasValidCalculation ? statusText : "Correct the marked fields before saving."; return }
        // All visible strings are already owned here, including the currently focused field.
        validateVisibleDraft()
        guard hasValidCalculation else { retainCurrentEntries(); errorMessage = "Entries are retained. Complete the marked fields to update totals."; return }
        let active = provider()
        guard active.generationToken == baseGeneration else { saveState = .providerChanged; return }
        saveState = .saving
        plan.updatedAtISO = ISO8601DateFormatter().string(from: now())
        do {
            var scratch = currentScratchpad
            scratch.canonical = plan
            _ = try active.fundingPlanRepo.savePlan(try Self.dto(from: plan), retaining: scratch.dto())
            retainedScratchpad = scratch; retentionPending = false
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
        let expected = committedCandidate
        do {
            try refresh(active)
            guard let canonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID), canonical == expected, provider().generationToken == baseGeneration, fundingPlanStore.generation == baseGeneration else { throw RepositoryStoreHydrationError.invalidFundingPlanState("saved plan missing") }
            completeCanonicalCommit(canonical)
            DeveloperConsole.shared.info(.database, "Funding plan saved and reloaded", metadata: ["code": "plan.saved", "effect": "committed and canonical data current"])
        } catch {
            saveState = .committedNeedsRefresh
            let failure = RuntimeDiagnostic.failure(error, operation: "plan save", stage: "post-commit canonical reload", effect: "plan committed; runtime data not current")
            errorMessage = "The plan was saved. Reload it before editing again."
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
            let sameOwner = active.generationToken == baseGeneration
            if sameOwner { try active.fundingPlanRepo.removeScratchpad(workspaceId: workspaceID, month: month.canonical) }
            rebaseFromPublishedPlan(generation: active.generationToken, restoringScratchpad: !sameOwner)
        } catch {
            errorMessage = "Canonical data could not be reloaded. Your draft is retained."
            saveState = .providerChanged
        }
    }

    private func rebaseFromPublishedPlan(generation: ProviderGenerationToken, restoringScratchpad: Bool = true) {
        retentionTask?.cancel(); commitTask?.cancel(); recurringTask?.cancel()
        retainedScratchpad = nil; retentionPending = false; excludedRecurringOccurrenceIDs = []
        preReductionBasis = [:]
        baseGeneration = generation
        baseCanonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID)
        plan = baseCanonical ?? Self.emptyPlan(month: month, workspaceID: workspaceID)
        isDirty = false; saveState = .ready; errorMessage = nil
        syncDraft(); captureDraftBase()
        if restoringScratchpad, restoreRetainedEntries() { return }
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
                completeCanonicalCommit(committedCandidate!)
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
        isDirty = hasEntryChanges
        if [.ready, .saved, .failed].contains(saveState) { saveState = .ready }
        errorMessage = nil
        hasOpenedPlanner = true
        scheduleRetention()
    }

    private var hasEntryChanges: Bool {
        guard var baseline = baseDraftPlan else { return true }
        // Live FX may update the open worksheet, but observing a newer quote
        // is not an edit to the owner's saved monthly entries. A real entry
        // change still retains the current quote with that change.
        if baseline.calculationVersion == .budgetV1, plan.calculationVersion == .budgetV1,
           baseline.referenceMode == .alDar, plan.referenceMode == .alDar {
            baseline.effectiveAlDarReference = plan.effectiveAlDarReference
        }
        return rawText != baseRawText || plan != baseline
    }

    private var currentScratchpad: MonthlyPlanScratchpad {
        .init(plan: plan, canonical: baseCanonical, rawText: rawText, fieldErrors: fieldErrors,
              untouchedZeroFields: untouchedZeroFields, unavailableBalanceAccountIDs: unavailableCurrentBalanceAccountIDs,
              preReductionBasis: preReductionBasis, excludedRecurringOccurrenceIDs: excludedRecurringOccurrenceIDs)
    }

    @discardableResult
    private func restoreRetainedEntries() -> Bool {
        guard fundingPlanStore.generation == baseGeneration,
              let scratch = fundingPlanStore.scratchpads.first(where: { $0.plan.workspaceID == workspaceID && $0.plan.month == month }) else { return false }
        isRebasing = true
        defer { isRebasing = false }
        plan = scratch.plan; rawText = scratch.rawText; fieldErrors = scratch.fieldErrors
        untouchedZeroFields = scratch.untouchedZeroFields
        unavailableCurrentBalanceAccountIDs = scratch.unavailableBalanceAccountIDs
        preReductionBasis = scratch.preReductionBasis
        excludedRecurringOccurrenceIDs = scratch.excludedRecurringOccurrenceIDs
        retainedScratchpad = scratch; retentionPending = false
        let canonical = fundingPlanStore.plan(for: month, workspaceID: workspaceID)
        baseCanonical = scratch.canonical
        if canonical != scratch.canonical {
            saveState = .canonicalChanged
            errorMessage = "The retained entries belong to an earlier version of this monthly plan. Review before reloading."
        } else { saveState = .ready }
        baseDraftPlan = canonical; baseRawText = rawText
        recalculate()
        return true
    }

    private func completeCanonicalCommit(_ canonical: FundingPlan) {
        plan = canonical; baseCanonical = canonical
        // Publishing a valid plan must never normalize a focused or retained string.
        baseDraftPlan = canonical; baseRawText = rawText; isDirty = false
        committedCandidate = nil; saveState = .saved; errorMessage = nil
        retentionPending = false; retainedScratchpad = currentScratchpad
        scheduleRecurringInclusion()
    }

    private func scheduleRetention() {
        guard !isRebasing, canEdit else { return }
        retentionPending = true
        retentionTask?.cancel(); commitTask?.cancel()
        let editingMonth = month, generation = baseGeneration
        retentionTask = Task { [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, self.month == editingMonth, self.baseGeneration == generation else { return }
            self.retainCurrentEntries()
            guard !self.retentionPending else { return }
            self.commitTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                guard let self, !Task.isCancelled, self.month == editingMonth, self.baseGeneration == generation else { return }
                self.commitTask = nil
                self.publishValidEntries()
            }
        }
    }

    private func retainCurrentEntries() {
        // The one-row scratchpad upsert is safe to retry at the next navigation
        // or quit boundary. A failed financial-plan transaction still requires
        // reload; it must not enter this retry path.
        guard canEdit || saveState == .retentionFailed,
              !requiresApplicationAvailability || ApplicationAvailability.shared.permitsMutation,
              provider().generationToken == baseGeneration, fundingPlanStore.generation == baseGeneration else { return }
        let snapshot = currentScratchpad
        var retainedEntries = retainedScratchpad
        if retainedEntries?.plan.calculationVersion == .budgetV1, snapshot.plan.calculationVersion == .budgetV1,
           retainedEntries?.plan.referenceMode == .alDar, snapshot.plan.referenceMode == .alDar {
            retainedEntries?.plan.effectiveAlDarReference = snapshot.plan.effectiveAlDarReference
        }
        guard snapshot != retainedEntries else { retentionPending = false; return }
        do {
            let lease = try DatabaseActivityGate.shared.begin(.repositoryWrite)
            defer { lease.finish() }
            try provider().fundingPlanRepo.saveScratchpad(snapshot.dto())
            retainedScratchpad = snapshot; retentionPending = false
            if saveState == .retentionFailed { saveState = .ready; errorMessage = nil }
        } catch {
            retentionPending = true; saveState = .retentionFailed
            errorMessage = "These changes could not be retained. Keep this window open and reopen the database before continuing."
            RuntimeDiagnostic.record(RuntimeDiagnostic.failure(error, operation: "monthly scratchpad", stage: "retain entries"), category: .database)
        }
    }

    /// Used at month/navigation/termination boundaries, before any pending task
    /// can observe another month's editor state.
    func flushPendingEntries() {
        retentionTask?.cancel(); retentionTask = nil
        commitTask?.cancel(); commitTask = nil
        guard hasOpenedPlanner else { return }
        if retentionPending || (isDirty && currentScratchpad != retainedScratchpad) { retainCurrentEntries() }
        publishValidEntries()
    }

    /// Runs before the app agrees to quit, while its repository is still open.
    /// A will-terminate notification is too late to recover a failed write.
    static func retainOpenWorkspacesBeforeTermination() -> Bool {
        var retained = true
        for workspace in openWorkspaces.allObjects {
            workspace.flushPendingEntries()
            if workspace.retentionPending || workspace.monthDrafts.values.contains(where: { $0.retentionPending }) {
                workspace.errorMessage = "LedgerForge stayed open because the latest monthly entries could not be retained. Reopen the database before quitting."
                retained = false
            }
        }
        return retained
    }

    private func publishValidEntries() {
        guard !retentionPending, isDirty, canSave else { return }
        if plan == baseCanonical {
            baseRawText = rawText; baseDraftPlan = plan; isDirty = false; saveState = .saved
            return
        }
        save()
    }

    /// Applied and removed occurrences keep their identity across salary windows,
    /// including unfinished plans retained only in a scratchpad. Use only the
    /// current workspace/provider and canonical-compatible retained state.
    private var recurringOccurrenceState: (retained: Set<String>, excluded: Set<String>) {
        guard provider().generationToken == baseGeneration, fundingPlanStore.generation == baseGeneration else { return ([], []) }
        let saved = fundingPlanStore.scratchpads.filter { scratch in
            scratch.plan.workspaceID == workspaceID &&
                scratch.canonical == fundingPlanStore.plan(for: scratch.plan.month, workspaceID: workspaceID)
        }
        let drafts = monthDrafts.filter { entry in
            let (month, state) = entry
            return state.generation == baseGeneration && state.plan.workspaceID == workspaceID &&
                state.canonical == fundingPlanStore.plan(for: month, workspaceID: workspaceID)
        }
        let savedRetained = Dictionary(uniqueKeysWithValues: saved.map {
            ($0.plan.month, Set($0.plan.assistance?.appliedRecurringIDs.keys.map { $0 } ?? []))
        })
        let draftRetained = Dictionary(uniqueKeysWithValues: drafts.map { entry in
            (entry.key, Set(entry.value.plan.assistance?.appliedRecurringIDs.keys.map { $0 } ?? []))
        })
        let savedExcluded = Dictionary(uniqueKeysWithValues: saved.map { ($0.plan.month, $0.excludedRecurringOccurrenceIDs) })
        let draftExcluded = Dictionary(uniqueKeysWithValues: drafts.map { ($0.key, $0.value.excludedRecurringOccurrenceIDs) })
        return (
            PlanningIntelligence.resolvedOccurrenceIDs(currentMonth: month,
                currentIDs: Set(plan.assistance?.appliedRecurringIDs.keys.map { $0 } ?? []),
                savedByMonth: savedRetained, draftByMonth: draftRetained),
            PlanningIntelligence.resolvedOccurrenceIDs(currentMonth: month, currentIDs: excludedRecurringOccurrenceIDs,
                savedByMonth: savedExcluded, draftByMonth: draftExcluded)
        )
    }
    var retainedRecurringOccurrenceIDs: Set<String> { recurringOccurrenceState.retained }
    var recurringOccurrenceExclusions: Set<String> { recurringOccurrenceState.excluded }

    private func scheduleRecurringInclusion() {
        guard hasOpenedPlanner, canEdit, plan.calculationVersion == .budgetV1,
              intelligenceStore.generation == baseGeneration, let metadata = intelligenceStore.snapshot else { return }
        recurringTask?.cancel()
        let editingMonth = month, generation = baseGeneration, revision = intelligenceStore.revision
        let start = plan.recurringStart, end = plan.recurringEnd
        let retainedOccurrenceIDs = retainedRecurringOccurrenceIDs
        let exclusions = recurringOccurrenceExclusions
        let transactions = transactionStore.transactions, sources = intelligenceStore.sources
        let cards = CardStore.shared.snapshot, categories = CategoryStore.shared.snapshot
        recurringTask = Task { [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            do {
                let work = Task.detached(priority: .userInitiated) {
                    let rows = try SpendingIntelligence.rows(transactions: transactions, sources: sources, cards: cards,
                        categories: categories, salaryRuleIDs: metadata.preferences?.salaryRuleIDs ?? [])
                    return try PlanningIntelligence.payments(metadata: metadata, rows: rows, sources: sources, start: start, end: end,
                        retaining: retainedOccurrenceIDs, excluding: exclusions)
                }
                let payments = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                guard !Task.isCancelled, let self, self.month == editingMonth, self.baseGeneration == generation,
                      self.provider().generationToken == generation, self.intelligenceStore.revision == revision,
                      self.plan.recurringStart == start, self.plan.recurringEnd == end, self.canEdit,
                      self.retainedRecurringOccurrenceIDs == retainedOccurrenceIDs,
                      self.recurringOccurrenceExclusions == exclusions else { return }
                let eligible = Set(self.eligibleAccounts.compactMap(\.repositoryAccountId))
                let additions = payments.filter { !($0.isExcludedFromPlan) && eligible.contains($0.definition.accountID) &&
                    self.plan.assistance?.appliedRecurringIDs[$0.id] == nil && !exclusions.contains($0.id) }
                if !additions.isEmpty { self.applyRecurring(additions) }
            } catch is CancellationError { }
            catch {
                self?.errorMessage = "Confirmed recurring payments could not be loaded. Your monthly entries are retained."
            }
        }
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
            for value in values where value.isInAccountScope(excluding: excludedHistoryAccountIDs, fundingOverrides: plan.assistance?.billFundingAccounts) {
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
        case .capturedAccountBalance(let time): return "Captured \(AppDateDisplay.isoTimestamp(time))"
        case .carried(let id): return fundingPlanStore.plans.first(where: { $0.id == id }).map { "Copied from \(Self.monthTitle($0.month))" } ?? "Copied from an earlier plan"
        }
    }

    func balanceProvenanceText(_ balance: FundingPlanBalance) -> String {
        if case .manual = balance.provenance { return "Your estimate" }
        let financial = balance.financialBalanceDate.map { "Statement balance as of \($0.presentation)" } ?? "Statement balance date not retained"
        return financial + " · " + provenanceText(balance.provenance)
    }

    var generation: ProviderGenerationToken { baseGeneration }

    func updateAssistance(_ value: PlanAssistance) {
        guard canEdit, value.workspaceID == plan.workspaceID, value.month == month.canonical else { return }
        plan.assistance = value
        markEdited(); recalculate()
    }

    /// Retain date changes automatically without silently removing a bill.
    @discardableResult
    func setSalaryCycle(_ cycle: SalaryFundingCycle) -> Bool {
        var cycle = cycle
        if let previous = cycle.previousSavedPayday(in: intelligenceStore.snapshot) { cycle.previousPayday = previous }
        guard canEdit, (try? cycle.validated(month: month.canonical)) != nil else { return false }
        var assistance = plan.assistance ?? .init(workspaceID: plan.workspaceID, month: month.canonical)
        guard assistance.appliedRecurringIDs.allSatisfy({ id, rowID in
            (try? StatementDate(canonical: String(id.suffix(10)))).map { cycle.includesRecurring(dueOn: $0) } == true &&
            (plan.qatarCommitments + plan.indiaCommitments).first(where: { $0.id == rowID })?.dueDate.map { cycle.includesRecurring(dueOn: $0) } == true
        }) else {
            errorMessage = "A linked recurring payment falls outside these dates. Review its date or remove that row before changing the salary cycle."
            return false
        }
        if assistance.salaryCycle == nil {
            assistance.carriedBillDates = Dictionary(uniqueKeysWithValues: (plan.qatarCommitments + plan.indiaCommitments).compactMap { row in
                plan.dueDate(for: row).map { (row.id, $0.canonical) }
            })
        }
        assistance.salaryCycle = cycle
        plan.assistance = assistance
        markEdited(); recalculate()
        scheduleRecurringInclusion()
        return true
    }

    /// Apply monthly amounts without changing the confirmed recurring template.
    func applyRecurring(_ payments: [RecurringPaymentProjection]) {
        guard canEdit else { return }
        var assistance = plan.assistance ?? .init(workspaceID: plan.workspaceID, month: month.canonical)
        for payment in payments where plan.includesRecurring(payment.date) && !excludedPlanningAccountIDs.contains(payment.definition.accountID) {
            let region = payment.currency == "QAR" ? "qatar" : "india"
            guard ["QAR", "INR"].contains(payment.currency), let money = try? Money(amount: payment.remaining, currency: payment.currency) else { continue }
            excludedRecurringOccurrenceIDs.remove(payment.id)
            let id = assistance.appliedRecurringIDs[payment.id] ?? UUID().uuidString
            let row = FundingPlanCommitment(id: id, label: payment.definition.title, money: money, included: !payment.isWaived,
                fundingAccountID: payment.definition.accountID, provenance: .manual, recurs: false,
                remark: "Confirmed recurring commitment; remaining amount funded by this salary plan.", dueDate: payment.date)
            if region == "qatar" { plan.qatarCommitments.removeAll { $0.id == id }; plan.qatarCommitments.append(row) }
            else { plan.indiaCommitments.removeAll { $0.id == id }; plan.indiaCommitments.append(row) }
            assistance.appliedRecurringIDs[payment.id] = id
            assistance.carriedBillDates?[id] = nil
            if assistance.appliedRecurringPaid == nil { assistance.appliedRecurringPaid = [:] }
            assistance.appliedRecurringPaid?[payment.id] = try? PlanningAmount(Money(amount: payment.paid, currency: payment.currency))
            rawText["label.\(id)"] = row.label
            rawText["amount.\(id)"] = (try? money.canonicalDecimalString()).map(localized) ?? ""
        }
        plan.assistance = assistance
        markEdited(); recalculate()
    }

    /// Received net pay is cash already recorded, never another forecast income.
    /// A source anchor predating the credit cannot be treated as post-salary cash.
    func applySalary(_ proposal: SalaryAssistance, source: SpendingSourceRow) {
        guard canEdit, proposal.targetMonth == month.canonical,
              source.id == proposal.transactionID, source.isRegularSalary, source.currency == "QAR",
              intelligenceStore.generation == baseGeneration,
              intelligenceStore.snapshot?.salaries.contains(proposal) == true,
              !excludedPlanningAccountIDs.contains(source.accountID) else { return }
        var assistance = plan.assistance ?? .init(workspaceID: plan.workspaceID, month: month.canonical)
        if proposal.planningBasis == .creditMonth {
            var cycle = assistance.salaryCycle ?? SalaryFundingCycle.expected(month: month)!
            cycle.payday = proposal.financialDate; cycle.receivedSalaryID = proposal.id
            guard setSalaryCycle(cycle) else { return }
            assistance = plan.assistance!
        }
        if !assistance.appliedSalaryIDs.contains(proposal.id) { assistance.appliedSalaryIDs.append(proposal.id) }
        plan.assistance = assistance
        plan.expectedFixedEarnings = Self.zeroQAR; plan.expectedVariableEarnings = Self.zeroQAR
        plan.expectedDeductions = Self.zeroQAR; plan.deductions = []
        plan.expectedFixedProvenance = .manual; plan.expectedVariableProvenance = .manual; plan.expectedDeductionsProvenance = .manual
        if let account = eligibleAccounts.first(where: { $0.repositoryAccountId == source.accountID }) {
            captureAccountBalance(account)
            if let index = plan.balances.firstIndex(where: { $0.accountID == source.accountID }) {
                plan.balances[index].included = true
                if account.currentBalanceAsOfISO.map({ String($0.prefix(10)) >= proposal.financialDate }) != true {
                    plan.balances[index].money = nil
                    plan.balances[index].financialBalanceDate = nil
                    unavailableCurrentBalanceAccountIDs.insert(source.accountID)
                }
            }
        }
        for field in [MoneyField.fixed, .variable, .deductions] { rawText[field.rawValue] = localized("0.00"); fieldErrors[field.rawValue] = nil }
        for key in Array(rawText.keys) where key.hasPrefix("deduction.") { rawText[key] = nil; fieldErrors[key] = nil }
        if let balance = plan.balances.first(where: { $0.accountID == source.accountID }) {
            rawText["balance.\(source.accountID)"] = (try? balance.money?.canonicalDecimalString()).map(localized) ?? ""
        }
        markEdited(); recalculate()
    }

    @discardableResult
    func applyPayslip(_ statement: SalaryStatement, accountID: String) -> Bool {
        guard canEdit, payslipProposals.contains(statement),
              statement.evidence.financialPeriod == month,
              let account = eligibleAccounts.first(where: { $0.repositoryAccountId == accountID && $0.nativeCurrency.code == "QAR" }),
              let net = try? PlanningAmount(statement.evidence.printedNet) else { return false }
        var assistance = plan.assistance ?? .init(workspaceID: workspaceID, month: month.canonical)
        assistance.salaryCycle = assistance.salaryCycle ?? SalaryFundingCycle.expected(month: month)
        assistance.payslipFunding = .init(statementID: statement.id, fingerprintAlgorithm: statement.fingerprintAlgorithm,
            fingerprintDigest: statement.fingerprintDigest, accountID: accountID, net: net)
        plan.assistance = assistance
        // The reviewed source net already includes payroll deductions. Keep it
        // separate from the owner's additional income and expense estimates.
        plan.expectedFixedEarnings = Self.zeroQAR; plan.expectedVariableEarnings = Self.zeroQAR
        plan.expectedDeductions = Self.zeroQAR; plan.deductions = []
        plan.expectedFixedProvenance = .manual; plan.expectedVariableProvenance = .manual; plan.expectedDeductionsProvenance = .manual
        if !plan.balances.contains(where: { $0.accountID == accountID }) { captureAccountBalance(account) }
        if let index = plan.balances.firstIndex(where: { $0.accountID == accountID }) { plan.balances[index].included = true }
        for field in [MoneyField.fixed, .variable, .deductions] { rawText[field.rawValue] = localized("0.00"); fieldErrors[field.rawValue] = nil }
        for key in Array(rawText.keys) where key.hasPrefix("deduction.") { rawText[key] = nil; fieldErrors[key] = nil }
        markEdited(); recalculate()
        return true
    }

    func acknowledgePayslipInCapturedBalance() {
        guard canAcknowledgePayslipBalance, let link = plan.assistance?.payslipFunding,
              let balance = plan.balances.first(where: { $0.accountID == link.accountID && $0.included }),
              let money = balance.money, let amount = try? PlanningAmount(money), let date = balance.financialBalanceDate else { return }
        plan.assistance?.payslipFunding?.balanceAcknowledgement = .init(balanceID: balance.id, amount: amount, financialDate: date.canonical)
        markEdited(); recalculate()
    }

    func removePayslipEstimate() {
        guard canEdit else { return }
        plan.assistance?.payslipFunding = nil
        markEdited(); recalculate()
    }

    func dismissError() { errorMessage = nil }

    private func recalculate() {
#if DEBUG
        let timing = GmailQualificationTiming.begin(.fundingCalculation)
        defer { GmailQualificationTiming.end(.fundingCalculation, started: timing) }
#endif
        if hasOpenedPlanner, canEdit, hasValidCalculation, plan.calculationVersion == .budgetV1, plan.referenceMode == .alDar,
           provider().generationToken == baseGeneration, fundingPlanStore.generation == baseGeneration {
            plan.effectiveAlDarReference = sharedINRReference.flatMap { try? $0.planningQuote() }
        }
        calculation = FundingPlanCalculator.calculate(plan, excludingAccounts: excludedPlanningAccountIDs,
            historyOnlyAccountIDs: excludedHistoryAccountIDs, salaryReceipt: payslipReceiptState)
        if saveState != .committedNeedsRefresh { isDirty = hasEntryChanges }
        if hasOpenedPlanner, !isRebasing, canEdit, isDirty, currentScratchpad != retainedScratchpad { scheduleRetention() }
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
                           calculationVersion: .budgetV1, keepInCBQ: zero,
                           assistance: .init(workspaceID: workspaceID, month: month.canonical, salaryCycle: SalaryFundingCycle.expected(month: month)))
    }

    private func plannerAccounts(type: AccountType) -> [Account] {
        // Native currency and typed role own eligibility; names and institution do not establish a subtype.
        accountStore.accounts.filter {
            guard let repositoryID = $0.repositoryAccountId, !repositoryID.isEmpty else { return false }
            return ($0.status == .active || selectedHistoryAccountIDs.contains(repositoryID)) && $0.type == type && ["QAR", "INR"].contains($0.nativeCurrency.code) && !excludedPlanningAccountIDs.contains(repositoryID)
        }.sorted { ($0.nativeCurrency.code, $0.name, $0.repositoryAccountId ?? "") < ($1.nativeCurrency.code, $1.name, $1.repositoryAccountId ?? "") }
    }

    private static func dto(from plan: FundingPlan) throws -> FundingPlanDTO {
        try plan.persistenceDTO()
    }

}

@MainActor
final class PlanningAnalysisModel: ObservableObject {
    @Published private(set) var projection: PlanningProjection?
    @Published private(set) var rows: [SpendingSourceRow] = []
    @Published private(set) var isWorking = false
    private var task: Task<Void, Never>?
    private var sequence = 0
    private var cachedGeneration: ProviderGenerationToken?
    private var cachedRevision: UInt64?

    private struct Query: Equatable {
        let generation: ProviderGenerationToken
        let revision: UInt64
        let plan: FundingPlan
        let scenario: PlanningScenario
        let today: StatementDate
        let selectedHistoryAccountIDs: Set<String>
        let retainedRecurringOccurrenceIDs: Set<String>
        let excludedRecurringOccurrenceIDs: Set<String>
    }
    private var query: Query?
    func cancel() {
        // An interrupted request has not produced the displayed projection.
        // Revisiting that plan must restart it, even when an older result exists.
        if isWorking { query = nil }
        sequence += 1; task?.cancel(); isWorking = false
    }
    func refresh(plan: FundingPlan, scenario: PlanningScenario, selectedHistoryAccountIDs: Set<String> = [],
                 retainedRecurringOccurrenceIDs: Set<String> = [], excludedRecurringOccurrenceIDs: Set<String> = []) {
        let store = FinancialIntelligenceStore.shared
        guard let generation = store.generation, let metadata = store.snapshot, generation == DatabaseProvider.shared.generationToken else {
            cancel(); query = nil; projection = nil; rows = []; return
        }
        let today = FinancialCalendar.statement(Date())!
        let requested = Query(generation: generation, revision: store.revision, plan: plan, scenario: scenario, today: today,
            selectedHistoryAccountIDs: selectedHistoryAccountIDs, retainedRecurringOccurrenceIDs: retainedRecurringOccurrenceIDs,
            excludedRecurringOccurrenceIDs: excludedRecurringOccurrenceIDs)
        guard query != requested || (projection == nil && !isWorking) else { return }
        cancel(); query = requested
        if cachedGeneration != generation || cachedRevision != store.revision { projection = nil }
        let revision = store.revision, source = store.sources, categories = CategoryStore.shared.snapshot, cards = CardStore.shared.snapshot
        let transactions = TransactionStore.shared.transactions
        let anchors = AccountStore.shared.accounts.compactMap { account -> PlanningAccountAnchor? in
            guard let id = account.repositoryAccountId else { return nil }
            let date = account.currentBalanceAsOfISO.flatMap { try? StatementDate(canonical: String($0.prefix(10))) }
            return .init(id: id, title: account.preferredDisplayName, currency: account.currencyCode, domain: account.type == .bank ? "bank" : "credit_card",
                amount: date == nil ? nil : account.currentBalance, date: date, historyOnly: account.isHistoryOnly)
        }
        let cached = cachedGeneration == generation && cachedRevision == revision ? rows : nil
        let request = sequence
        isWorking = true
        task = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(160)) } catch { return }
            let work = Task.detached(priority: .userInitiated) {
                let rows = try cached ?? SpendingIntelligence.rows(transactions: transactions, sources: source, cards: cards, categories: categories, salaryRuleIDs: metadata.preferences?.salaryRuleIDs ?? [])
                return (rows, try PlanningIntelligence.project(plan: plan, anchors: anchors, rows: rows, metadata: metadata, sources: source, cards: cards, today: today, scenario: scenario,
                    selectedHistoryAccountIDs: selectedHistoryAccountIDs, retainedRecurringOccurrenceIDs: retainedRecurringOccurrenceIDs,
                    excludedRecurringOccurrenceIDs: excludedRecurringOccurrenceIDs))
            }
            guard let (rows, projection) = try? await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() }) else { return }
            guard let self, !Task.isCancelled, self.sequence == request, store.generation == generation, store.revision == revision else { return }
            self.cachedGeneration = generation; self.cachedRevision = revision
            self.rows = rows; self.projection = projection; self.isWorking = false
        }
    }
}
