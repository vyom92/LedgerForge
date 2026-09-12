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

    static func asOfLabel(for date: StatementDate?) -> String {
        date.map { "As of \($0.presentation)" } ?? "Date unavailable"
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
/// It deliberately mirrors the accepted selectors in RepositoryStoreHydrator:
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
            .filter { $0.type == .bank || $0.type == .creditCard }
            .sorted(by: accountOrdering)

        let bankPositions = members.compactMap { account -> (CurrencyCode, DashboardAccountPosition)? in
            guard account.type == .bank else { return nil }
            let selected = selectedBankBalance(for: account, transactions: transactions)
            let amount = selected?.money.currency == account.nativeCurrency ? selected?.money : nil
            let position = DashboardAccountPosition(
                id: positionID(for: account),
                displayName: account.nickname ?? account.name,
                institution: account.institution,
                amount: amount,
                asOf: amount == nil ? nil : selected?.date,
                sourceContext: nil
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
                displayName: account.nickname ?? account.name,
                institution: account.institution,
                amount: amount,
                asOf: amount == nil ? nil : selected?.statementDate,
                sourceContext: amount == nil || selected?.statementDate != nil
                    ? nil
                    : sourceContext(for: selected)
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

    private static func selectedBankBalance(
        for account: Account,
        transactions: [Transaction]
    ) -> (money: Money, date: StatementDate)? {
        guard let accountID = account.repositoryAccountId else { return nil }
        let dated = transactions.compactMap { transaction -> (transaction: Transaction, money: Money, date: StatementDate)? in
            guard transaction.repositoryAccountId == accountID,
                  let date = transaction.statementDate,
                  let money = transaction.runningBalanceMoney else {
                return nil
            }
            return (transaction, money, date)
        }
        guard let latestDate = dated.map(\.date).max() else { return nil }
        let candidates = dated.filter { $0.date == latestDate }
        let selected: (transaction: Transaction, money: Money, date: StatementDate)?
        if let documentID = candidates.first?.transaction.documentScopedSourceOrder?.documentID,
           candidates.allSatisfy({ $0.transaction.documentScopedSourceOrder?.documentID == documentID }) {
            selected = candidates.max {
                ($0.transaction.documentScopedSourceOrder?.ordinal ?? 0) <
                ($1.transaction.documentScopedSourceOrder?.ordinal ?? 0)
            }
        } else {
            selected = candidates.count == 1 ? candidates.first : nil
        }
        guard let selected, selected.money.currency == account.nativeCurrency else { return nil }
        return (selected.money, selected.date)
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
            return "Statement month \(month.canonical)"
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
    case investment = "Available for investment"

    var id: String { rawValue }
    var currencyCode: String { self == .indiaShortfall ? "INR" : "QAR" }

    func money(in calculation: FundingPlanCalculation?) -> Money? {
        switch self {
        case .expected: calculation?.expectedNet
        case .indiaShortfall: calculation?.indiaFundingShortfall
        case .principal: calculation?.requiredQARPrincipal
        case .investment: calculation?.availableForInvestment
        }
    }
}

enum DashboardRoute: String, CaseIterable {
    case transactions = "View Transactions"
    case imports = "Open Import"
    case salary = "Open Salary"

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
    @Published private(set) var recentActivity: [TransactionPresentationRow] = []
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var transactionCount = 0
    @Published private(set) var positionState: DashboardContentState = .loading
    @Published private(set) var recentActivityState: DashboardContentState = .loading
    @Published private(set) var fundingState: DashboardContentState = .loading
    @Published private(set) var fundingCalculation: FundingPlanCalculation?
    @Published private(set) var fundingRateContext: String?

    private let accountStore: AccountStore
    private let transactionStore: TransactionStore
    private let cardStore: CardStore
    private let categoryStore: CategoryStore
    private let fundingPlanStore: FundingPlanStore
    private let availability: ApplicationAvailability
    private let now: () -> Date
    private let workspaceID: String
    private var cancellables = Set<AnyCancellable>()
    // Retains the existing bounded Dashboard display size; it is not a financial rule.
    private let recentActivityLimit = 3

    init(
        accountStore: AccountStore = .shared,
        transactionStore: TransactionStore = .shared,
        cardStore: CardStore = .shared,
        categoryStore: CategoryStore = .shared,
        fundingPlanStore: FundingPlanStore = .shared,
        availability: ApplicationAvailability = .shared,
        workspaceID: String = "default-workspace",
        now: @escaping () -> Date = Date.init
    ) {
        self.accountStore = accountStore
        self.transactionStore = transactionStore
        self.cardStore = cardStore
        self.categoryStore = categoryStore
        self.fundingPlanStore = fundingPlanStore
        self.availability = availability
        self.workspaceID = workspaceID
        self.now = now
        // Every notification reads the complete already-installed canonical stores,
        // instead of combining captured values from different publication moments.
        Publishers.MergeMany([
            accountStore.$accounts.map { _ in () }.eraseToAnyPublisher(),
            transactionStore.$transactions.map { _ in () }.eraseToAnyPublisher(),
            cardStore.$snapshot.map { _ in () }.eraseToAnyPublisher(),
            categoryStore.$snapshot.map { _ in () }.eraseToAnyPublisher(),
            fundingPlanStore.$plans.map { _ in () }.eraseToAnyPublisher(),
            availability.$state.map { _ in () }.eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                .receive(on: RunLoop.main)
                .map { _ in () }
                .eraseToAnyPublisher()
        ])
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.refreshPresentation() }
        .store(in: &cancellables)
        refreshPresentation()
    }

    func markHydrationStarted() {
        presentationState = .loading("Loading persisted dashboard...")
        positionState = .loading
        recentActivityState = .loading
        fundingState = .loading
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
        presentationState = .failed("Dashboard load failed")
        positions = []
        recentActivity = []
        fundingCalculation = nil
        fundingRateContext = nil
        positionState = .unavailable
        recentActivityState = .unavailable
        fundingState = .unavailable
    }

    /// Observation only: never selects an account, seeds a plan, edits a draft,
    /// requests hydration, or calls a repository mutation.
    func refreshPresentation() {
        let state = availability.state
        let isCurrent = state == .current || state == .empty
        accounts = accountStore.accounts
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

        let category = categoryStore.snapshot
        let rows = isCurrent ? TransactionPresentationEngine.rows(
            transactions: transactionStore.transactions,
            accounts: accountStore.accounts,
            categories: category.categories,
            assignments: category.assignments
        ).sorted {
            TransactionPresentationEngine.comparison($0, $1, sort: .init()) == .orderedAscending
        } : []
        transactionCount = transactionStore.transactions.count
        recentActivity = Array(rows.prefix(recentActivityLimit))
        recentActivityState = .resolve(availability: state, isEmpty: rows.isEmpty)

        let currentMonth = Self.currentMonth(at: now())
        let fundingIsCurrent = isCurrent && fundingPlanStore.generation == availability.generation
        let plan = fundingIsCurrent
            ? currentMonth.flatMap { fundingPlanStore.plan(for: $0, workspaceID: workspaceID) }
            : nil
        fundingCalculation = plan.map(FundingPlanCalculator.calculate)
        fundingState = .resolve(availability: state, isEmpty: plan == nil)
        if (isCurrent && !fundingIsCurrent) || fundingCalculation?.incompleteReasons.contains(.invalidCurrency) == true {
            fundingState = .unavailable
        }
        fundingRateContext = nil
        if let fx = plan?.planningFX, fundingCalculation?.requiredQARPrincipal != nil {
            fundingRateContext = "Plan-local rate: 1 QAR = \(NSDecimalNumber(decimal: fx.inrPerQAR).stringValue) INR, observed \(fx.observationDate.presentation)."
        }
    }

    static func currentMonth(at date: Date) -> SelectedStatementMonth? {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        return try? SelectedStatementMonth(year: year, month: month)
    }
}
