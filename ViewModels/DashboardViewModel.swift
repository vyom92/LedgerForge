// LedgerForge — repository-backed Dashboard presentation.

import Foundation
import Combine

enum DashboardPresentationState: Equatable {
    case loading(String)
    case empty(String)
    case loaded(String)
    case failed(String)

    var message: String {
        switch self {
        case .loading(let message), .empty(let message), .loaded(let message), .failed(let message):
            return message
        }
    }
}

/// One repository-backed account position for Dashboard presentation. `amount`
/// is nil when the accepted source selector cannot establish a current value.
struct DashboardAccountPosition: Identifiable, Equatable {
    let id: String
    let displayName: String
    let institution: String
    let amount: Money?
    let asOf: StatementDate?
    /// Source period or source-selected month, preserved only when an exact
    /// source day is unavailable. It is never converted into an invented day.
    let sourceContext: String?
    /// The printed period's end is available for statement-age presentation,
    /// independently of the optional financial balance date above.
    let sourcePeriodEnd: StatementDate?

    static func asOfLabel(for date: StatementDate?, today: StatementDate? = nil) -> String {
        let current = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let day = today ?? (try? StatementDate(year: current.year ?? 0, month: current.month ?? 0, day: current.day ?? 0))
        guard let date, let day, let age = FinancialCalendar.distance(date, day) else { return "Date unavailable" }
        if age == 0 { return "Today" }
        if age == 1 { return "1 day ago" }
        if age > 1 { return "\(age) days ago" }
        return age == -1 ? "In 1 day" : "In \(-age) days"
    }
}

/// Native-currency Dashboard position. Bank cash and card amount owed remain
/// separate financial domains even when their native currency is the same.
struct DashboardCurrencyPosition: Identifiable, Equatable {
    let currency: CurrencyCode
    let banks: [DashboardAccountPosition]
    let cards: [DashboardAccountPosition]
    let bankTotal: Money?
    let cardTotal: Money?

    var id: String { currency.code }
}

/// Read-only presentation projection over the canonical hydrated runtime stores.
/// Bank amounts and dates use the single accepted hydration selector:
/// ADR-039 requires bank running-balance selection to fail closed on an
/// ambiguous latest cross-document date, and ADR-044 assigns card chronology
/// and liability semantics to the hydrated card graph.
enum DashboardPositionProjection {

    static func make(
        accounts: [Account],
        transactions: [Transaction],
        cardSnapshot: CardStoreSnapshot
    ) -> [DashboardCurrencyPosition] {
        let members = accounts
            .filter { ($0.type == .bank || $0.type == .creditCard) && !$0.isHistoryOnly }
            .sorted(by: accountOrdering)

        let bankPositions = members.compactMap { account -> (CurrencyCode, DashboardAccountPosition)? in
            guard account.type == .bank else { return nil }
            let date = account.currentBalanceAsOfISO.flatMap { try? StatementDate(canonical: $0) }
            let amount = date != nil && account.currentBalanceMoney.currency == account.nativeCurrency
                ? account.currentBalanceMoney : nil
            let position = DashboardAccountPosition(
                id: positionID(for: account),
                displayName: account.preferredDisplayName,
                institution: account.institutionDisplayName,
                amount: amount,
                asOf: amount == nil ? nil : date,
                sourceContext: nil,
                sourcePeriodEnd: nil
            )
            return (account.nativeCurrency, position)
        }

        let cardPositions = members.compactMap { account -> (CurrencyCode, DashboardAccountPosition)? in
            guard account.type == .creditCard else { return nil }
            let selected = selectedCardStatement(for: account, snapshot: cardSnapshot)
            let amount: Money?
            if let selected, let newBalance = selected.newBalance,
               selected.currency == account.nativeCurrency,
               newBalance.currency == account.nativeCurrency {
                // `newBalance` is the source amount owed; do not use the
                // sign-inverted Account runtime net-worth balance here.
                amount = newBalance
            } else {
                amount = nil
            }
            let position = DashboardAccountPosition(
                id: positionID(for: account),
                displayName: account.preferredDisplayName,
                institution: account.institutionDisplayName,
                amount: amount,
                asOf: amount == nil ? nil : selected?.statementDate,
                sourceContext: amount == nil || selected?.statementDate != nil
                    ? nil
                    : sourceContext(for: selected),
                sourcePeriodEnd: amount == nil ? nil : selected?.period?.end
            )
            return (account.nativeCurrency, position)
        }

        let currencies = Set(bankPositions.map(\.0)).union(cardPositions.map(\.0)).sorted()
        return currencies.map { currency in
            let banks = bankPositions.filter { $0.0 == currency }.map(\.1)
            let cards = cardPositions.filter { $0.0 == currency }.map(\.1)
            return DashboardCurrencyPosition(
                currency: currency,
                banks: banks,
                cards: cards,
                bankTotal: aggregate(banks, currency: currency),
                cardTotal: aggregate(cards, currency: currency)
            )
        }
    }

    private static func positionID(for account: Account) -> String {
        account.repositoryAccountId ?? account.id.uuidString
    }

    private static func accountOrdering(_ lhs: Account, _ rhs: Account) -> Bool {
        let left = (lhs.institution, lhs.nickname ?? lhs.name, positionID(for: lhs))
        let right = (rhs.institution, rhs.nickname ?? rhs.name, positionID(for: rhs))
        return left < right
    }

    private static func aggregate(
        _ positions: [DashboardAccountPosition],
        currency: CurrencyCode
    ) -> Money? {
        guard !positions.isEmpty,
              positions.allSatisfy({ $0.amount?.currency == currency }) else {
            return nil
        }
        return try? Money.aggregate(positions.compactMap(\.amount))
    }

    private static func selectedCardStatement(
        for account: Account,
        snapshot: CardStoreSnapshot
    ) -> CardStatement? {
        guard let accountID = account.repositoryAccountId else { return nil }
        let statements = snapshot.statements.filter { $0.liabilityAccountID == accountID }
        if statements.allSatisfy({ !$0.parserProfileID.hasPrefix("axis.credit-card.") }) {
            return statements.max {
                (($0.statementDate?.canonical ?? ""), ($0.period?.end.canonical ?? ""), $0.id) <
                (($1.statementDate?.canonical ?? ""), ($1.period?.end.canonical ?? ""), $1.id)
            }
        }

        func cycleMonth(_ statement: CardStatement) -> String? {
            if let month = statement.selectedStatementMonth { return month.canonical }
            if let date = statement.statementDate { return String(format: "%04d-%02d", date.year, date.month) }
            if let end = statement.period?.end { return String(format: "%04d-%02d", end.year, end.month) }
            return nil
        }

        let keyed = statements.compactMap { statement in cycleMonth(statement).map { ($0, statement) } }
        guard let latestMonth = keyed.map(\.0).max() else { return nil }
        let cycle = keyed.filter { $0.0 == latestMonth }.map(\.1)
        if let exactDate = cycle.compactMap(\.statementDate).max() {
            let exact = cycle.filter { $0.statementDate == exactDate }
            let groupIDs = Set(exact.compactMap(\.semanticGroupID))
            return exact.count == 1 || (groupIDs.count == 1 && exact.allSatisfy({ $0.semanticGroupID != nil }))
                ? exact.first
                : nil
        }
        let groupIDs = Set(cycle.compactMap(\.semanticGroupID))
        return cycle.count == 1 || (groupIDs.count == 1 && cycle.allSatisfy({ $0.semanticGroupID != nil }))
            ? cycle.first
            : nil
    }

    private static func sourceContext(for statement: CardStatement?) -> String? {
        guard let statement else { return nil }
        if let period = statement.period {
            return "Statement period \(period.start.presentation)–\(period.end.presentation)"
        }
        if let month = statement.selectedStatementMonth {
            return "Statement month \(AppDateDisplay.month(month.canonical))"
        }
        return nil
    }
}

enum DashboardContentState: Equatable {
    case loading, empty, populated, unavailable

    static func resolve(availability: ApplicationDataState, isEmpty: Bool) -> Self {
        switch availability {
        case .loading: .loading
        case .unavailable, .retainedNonCurrent: .unavailable
        case .current, .empty: isEmpty ? .empty : .populated
        }
    }
}

/// Labels map the existing saved-plan result; this type owns no calculation.
enum DashboardFundingMetric: String, CaseIterable, Identifiable {
    case expected = "Expected this month"
    case indiaShortfall = "India funding shortfall"
    case principal = "Required QAR principal"
    case investment = "Funding margin"

    var id: String { rawValue }
    var currencyCode: String { self == .indiaShortfall ? "INR" : "QAR" }

    func money(in calculation: FundingPlanCalculation?) -> Money? {
        switch self {
        case .expected: calculation?.expectedNet
        case .indiaShortfall: calculation?.indiaFundingShortfall
        case .principal: calculation?.requiredQARPrincipal
        case .investment: calculation?.finalQARBuffer
        }
    }
}

enum DashboardRoute: String, CaseIterable {
    case transactions = "View Transactions"
    case imports = "Open Import"
    case salary = "Open Budget Planning"

    var destination: AppShellSection {
        switch self {
        case .transactions: .transactions
        case .imports: .imports
        case .salary: .salary
        }
    }
}

/// Only passes through an existing explicit current Import review route.
/// It does not scan history or infer a financial warning.
enum DashboardAttentionProjection {
    static func presentation(for route: ConfirmedImportRecoveryRoute?) -> ConfirmedImportRecoveryPresentation? {
        guard let route, case .reviewRequired = route else { return nil }
        return ConfirmedImportRecoveryPresentationMapper.presentation(for: route)
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var presentationState: DashboardPresentationState = .loading("Loading persisted dashboard...")
    @Published private(set) var positions: [DashboardCurrencyPosition] = []
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var storedTransactionCount = 0
    @Published private(set) var positionState: DashboardContentState = .loading
    @Published private(set) var fundingState: DashboardContentState = .loading
    @Published private(set) var fundingCalculation: FundingPlanCalculation?
    @Published private(set) var fundingMessage: String?
    @Published private(set) var fundingRateDetail: String?
    @Published private(set) var netWorthReport: NetWorthReport = .withdrawn(.loading)

    var fundingMonthTitle: String {
        selectedFundingMonth.map(SalaryWorkspaceViewModel.monthTitle) ?? "Month unavailable"
    }

    var fundingPlanTitle: String {
        guard let month = selectedFundingMonth else { return "Monthly plan" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.monthSymbols[month.month - 1] + " plan"
    }

    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let cardStore: CardStore
    private let fundingPlanStore: FundingPlanStore
    private weak var fundingWorkspace: SalaryWorkspaceViewModel?
    private let intelligenceStore: FinancialIntelligenceStore
    private let investmentStore: InvestmentStore
    private let membershipStore: NetWorthMembershipStore
    private let reportingPreferences: ReportingCurrencyPreferences
    private let reportingRates: AlDarReferenceSession?
    private let reportingPrices: InvestmentPriceSession?
    private let gmail: GmailIntakeSession
    private let availability: ApplicationAvailability
    private let now: () -> Date
    private let workspaceID: String
    private var selectedFundingMonth: SelectedStatementMonth?
    private var cancellables = Set<AnyCancellable>()
    private var pendingRefreshID: UUID?

    init(
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        cardStore: CardStore = .shared,
        fundingPlanStore: FundingPlanStore = .shared,
        intelligenceStore: FinancialIntelligenceStore = .shared,
        investmentStore: InvestmentStore = .shared,
        membershipStore: NetWorthMembershipStore = .shared,
        reportingPreferences: ReportingCurrencyPreferences = .shared,
        reportingRates: AlDarReferenceSession? = nil,
        reportingPrices: InvestmentPriceSession? = nil,
        gmail: GmailIntakeSession = .shared,
        availability: ApplicationAvailability = .shared,
        workspaceID: String = "default-workspace",
        fundingMonth: SelectedStatementMonth? = nil,
        fundingWorkspace: SalaryWorkspaceViewModel? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.cardStore = cardStore
        self.fundingPlanStore = fundingPlanStore
        self.fundingWorkspace = fundingWorkspace
        self.intelligenceStore = intelligenceStore
        self.investmentStore = investmentStore
        self.membershipStore = membershipStore
        self.reportingPreferences = reportingPreferences
        self.reportingRates = reportingRates
        self.reportingPrices = reportingPrices
        self.gmail = gmail
        self.availability = availability
        self.workspaceID = workspaceID
        self.selectedFundingMonth = fundingMonth ?? Self.currentMonth(at: now())
        self.now = now
        // Every notification reads the complete already-installed canonical stores,
        // instead of combining captured values from different publication moments.
        Publishers.MergeMany([
            accountStore.$accounts.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            transactionStore.$transactions.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            cardStore.$snapshot.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            fundingPlanStore.$plans.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            intelligenceStore.$snapshot.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            investmentStore.$snapshot.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            membershipStore.$snapshot.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            reportingPreferences.$currencies.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            gmail.$coverage.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ])
        .sink { [weak self] in self?.requestPresentationRefresh() }
        .store(in: &cancellables)

        reportingRates?.objectWillChange.sink { [weak self] _ in self?.requestPresentationRefresh() }.store(in: &cancellables)
        reportingPrices?.objectWillChange.sink { [weak self] _ in self?.requestPresentationRefresh() }.store(in: &cancellables)
        fundingWorkspace?.objectWillChange.sink { [weak self] _ in self?.requestPresentationRefresh() }.store(in: &cancellables)

        // These stores publish on the main actor after installing their backing
        // values. One queued refresh reads that whole snapshot. Availability
        // withdrawal is synchronous, so stale financial content is never kept
        // current while waiting for the queued work.
        availability.$state.dropFirst()
            .sink { [weak self] state in
                guard let self else { return }
                if state == .current || state == .empty {
                    self.requestPresentationRefresh()
                } else {
                    self.invalidatePresentation(for: state)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.requestPresentationRefresh() }
        .store(in: &cancellables)
        refreshPresentation()
    }

    func markHydrationStarted() {
        invalidatePresentation(for: .loading)
    }

    func selectFundingMonth(_ month: SelectedStatementMonth) {
        guard selectedFundingMonth != month else { return }
        selectedFundingMonth = month
        refreshPresentation()
    }

    func markHydrationCompleted(_ result: RepositoryStoreHydrationResult) {
        refreshPresentation()
        if result.accountCount == 0 && result.transactionCount == 0 {
            presentationState = .empty("No persisted dashboard data")
        } else {
            presentationState = .loaded("Loaded \(result.accountCount) account(s), \(result.transactionCount) transaction(s)")
        }
    }

    func markHydrationFailed(_ error: Error) {
        invalidatePresentation(for: .unavailable)
    }

    private func requestPresentationRefresh() {
        guard pendingRefreshID == nil else { return }
        let requestID = UUID()
        pendingRefreshID = requestID
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingRefreshID == requestID else { return }
            self.refreshPresentation()
        }
    }

    private func invalidatePresentation(for state: ApplicationDataState) {
        pendingRefreshID = nil
        let loading = state == .loading
        presentationState = loading
            ? .loading("Loading persisted dashboard...")
            : .failed("Dashboard load failed")
        positions = []
        fundingCalculation = nil
        fundingMessage = nil
        fundingRateDetail = nil
        netWorthReport = .withdrawn(loading ? .loading : .unavailable)
        positionState = loading ? .loading : .unavailable
        fundingState = loading ? .loading : .unavailable
    }

    /// Observation only: never selects an account, seeds a plan, edits a draft,
    /// requests hydration, or calls a repository mutation.
    func refreshPresentation() {
        pendingRefreshID = nil
        let state = availability.state
        let isCurrent = state == .current || state == .empty
        accounts = accountStore.accounts
        storedTransactionCount = transactionStore.transactions.count
        switch state {
        case .loading:
            presentationState = .loading("Loading persisted dashboard...")
        case .unavailable, .retainedNonCurrent:
            presentationState = .failed("Dashboard load failed")
        case .current, .empty:
            presentationState = accounts.isEmpty && transactionStore.transactions.isEmpty
                ? .empty("No persisted dashboard data")
                : .loaded("Loaded \(accounts.count) account(s), \(transactionStore.transactions.count) transaction(s)")
        }
        positions = isCurrent ? DashboardPositionProjection.make(
            accounts: accountStore.accounts,
            transactions: transactionStore.transactions,
            cardSnapshot: cardStore.snapshot
        ) : []
        positionState = .resolve(availability: state, isEmpty: positions.isEmpty)
        if !isCurrent {
            netWorthReport = .withdrawn(state == .loading ? .loading : .unavailable)
        } else if membershipStore.generation != availability.generation || investmentStore.generation != availability.generation {
            netWorthReport = .withdrawn(.membershipUnavailable)
        } else {
            let coverage = gmail.coverage.flatMap { $0.generation == availability.generation ? $0 : nil }
            netWorthReport = NetWorthProjection.make(accounts: accounts, positions: positions,
                investments: investmentStore.snapshot, valuations: reportingPrices?.valuations ?? [:],
                membership: membershipStore.snapshot, currencies: reportingPreferences.currencies,
                legs: reportingRates?.legs ?? [:], rateFailures: reportingRates?.failures ?? [],
                priceFailures: Set(reportingPrices?.failures.keys.map { $0 } ?? []),
                scopeNotes: NetWorthProjection.scopeNotes(inbox: coverage?.inbox, importedSourceIDs: coverage?.importedSourceIDs ?? []),
                now: now(), generation: availability.generation)
        }

        let fundingIsCurrent = isCurrent && fundingPlanStore.generation == availability.generation
        let canonicalPlan = fundingIsCurrent
            ? selectedFundingMonth.flatMap { fundingPlanStore.plan(for: $0, workspaceID: workspaceID) }
            : nil
        var plan = canonicalPlan
        var retained: MonthlyPlanScratchpad?
        fundingMessage = nil
        fundingRateDetail = nil
        if fundingIsCurrent, let month = selectedFundingMonth, let generation = availability.generation {
            let presentation = fundingWorkspace?.retainedPlanPresentation(for: month, workspaceID: workspaceID,
                generation: generation, canonical: canonicalPlan)
            if let presentation {
                switch presentation {
                case .canonical: break
                case .retained(let entries): retained = entries
                case .unavailable(let message): fundingMessage = message
                }
            } else {
                retained = fundingPlanStore.scratchpads.first { $0.plan.workspaceID == workspaceID && $0.plan.month == month }
            }
        }
        if let retained {
            if retained.canonical == canonicalPlan {
                plan = retained.plan
            } else {
                fundingMessage = "The retained entries belong to an earlier plan. Open Budget Planning to review them."
            }
        }
        let intelligence = intelligenceStore
        let excluded = (intelligence.generation == availability.generation ? intelligence.snapshot?.preferences?.excludedPlanningAccountIDs ?? [] : [])
            .union(AccountPresentationScope.historyOnlyIDs(in: accounts))
        let historyOnlyIDs = AccountPresentationScope.historyOnlyIDs(in: accounts)
        if fundingMessage == nil, let retained, Self.hasIncompleteEntries(retained, excludedAccountIDs: excluded, historyOnlyIDs: historyOnlyIDs) {
            fundingMessage = "Latest entries are retained. Complete the marked fields in Budget Planning to see the updated amounts."
        }
        fundingCalculation = fundingMessage == nil ? plan.map { FundingPlanCalculator.calculate($0, excludingAccounts: excluded,
            historyOnlyAccountIDs: AccountPresentationScope.historyOnlyIDs(in: accounts),
            salaryReceipt: PayslipReceiptState.resolve(plan: $0, transactions: transactionStore.transactions, excludedAccounts: excluded)) } : nil
        fundingRateDetail = plan.map(Self.rateDetail)
        fundingState = .resolve(availability: state, isEmpty: plan == nil)
        if (isCurrent && !fundingIsCurrent) || fundingMessage != nil || fundingCalculation?.incompleteReasons.contains(.invalidCurrency) == true {
            fundingState = .unavailable
        }
    }

    private static func hasIncompleteEntries(_ entries: MonthlyPlanScratchpad, excludedAccountIDs: Set<String>, historyOnlyIDs: Set<String>) -> Bool {
        let plan = entries.plan
        let hiddenBills = Set((plan.qatarCommitments + plan.indiaCommitments).filter {
            !$0.isInAccountScope(excluding: historyOnlyIDs, fundingOverrides: plan.assistance?.billFundingAccounts)
        }.map(\.id))
        return entries.fieldErrors.keys.contains { key in
            if key.hasPrefix("balance.") { return !excludedAccountIDs.contains(String(key.dropFirst("balance.".count))) }
            for prefix in ["amount.", "label."] where key.hasPrefix(prefix) {
                return !hiddenBills.contains(String(key.dropFirst(prefix.count)))
            }
            return true
        }
    }

    private static func rateDetail(_ plan: FundingPlan) -> String {
        if plan.calculationVersion == .budgetV1, plan.referenceMode == .alDar {
            guard let quote = plan.effectiveAlDarReference, quote.submittedQAR.amount == 1 else {
                return "This plan has no effective Al Dar rate."
            }
            return "Plan rate · 1 QAR = \(quote.returnedINR.rawToken) INR\nAl Dar reference fetched \(AppDateDisplay.isoTimestamp(quote.fetchedAtISO))."
        }
        if let rate = plan.planningFX {
            return "Plan rate · 1 QAR = \(NSDecimalNumber(decimal: rate.inrPerQAR).stringValue) INR\nManual reference dated \(rate.observationDate.presentation)."
        }
        if let quote = plan.alDarReference?.quote {
            return "Plan rate · 1 QAR ≈ \(quote.displayRate) INR\nAl Dar reference fetched \(AppDateDisplay.isoTimestamp(quote.fetchedAtISO))."
        }
        return "This plan has no effective exchange rate."
    }

    static func currentMonth(at date: Date) -> SelectedStatementMonth? {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        return try? SelectedStatementMonth(year: year, month: month)
    }
}
