import Foundation
import Testing
@testable import LedgerForge

@Suite("DashboardViewModel", .serialized)
@MainActor
struct DashboardViewModelTests {

    @Test(.globalRuntimeStateIsolation)
    func currentDatabaseProjectionMatchesIndependentOracleAndDoesNotMutateReadOnlyFiles() throws {
        let context = try dashboardCurrentDatabaseContext()
        let before = try databaseFiles(context)
        let availability = ApplicationAvailability()
        availability.didHydrate(context.snapshot.hydrationResult, generation: context.provider.generationToken)

        let viewModel = DashboardViewModel(
            accountStore: context.accountStore,
            transactionStore: context.transactionStore,
            cardStore: context.cardStore,
            categoryStore: context.categoryStore,
            fundingPlanStore: context.fundingPlanStore,
            availability: availability,
            workspaceID: context.workspaceID,
            now: Date.init
        )
        viewModel.refreshPresentation()

        let expectedPositions = dashboardPositionOracle(snapshot: context.snapshot)
        assertPositions(viewModel.positions, equalTo: expectedPositions)
        check(
            viewModel.positionState == DashboardContentState.resolve(
                availability: availability.state,
                isEmpty: expectedPositions.isEmpty
            ),
            "Dashboard position state follows canonical availability"
        )
        assertCanonicalBalancesMatchSelectedEvidence(snapshot: context.snapshot)

        let expectedRecentActivity = recentActivityOracle(snapshot: context.snapshot)
        assertRecentActivity(viewModel.recentActivity, equalTo: expectedRecentActivity)
        check(viewModel.recentActivityState == DashboardContentState.resolve(
            availability: availability.state,
            isEmpty: context.snapshot.transactions.isEmpty
        ), "Dashboard activity state follows canonical availability")
        check(viewModel.accounts.count == context.snapshot.accounts.count, "Dashboard account mirror is observation-only")
        check(viewModel.transactionCount == context.snapshot.transactions.count, "Dashboard transaction count reflects hydrated store")

        check(
            Set(viewModel.positions.map(\.currency)).count == viewModel.positions.count,
            "Dashboard currency groups are unique"
        )
        check(
            try databaseFiles(context) == before,
            "Dashboard observation leaves read-only database and WAL bytes unchanged"
        )

        if context.snapshot.cardSnapshot.statements.isEmpty {
            notObserved("card-position-shape")
        }
        if Set(context.snapshot.accounts.filter { $0.type == .bank || $0.type == .creditCard }.map(\.nativeCurrency)).count < 2 {
            notObserved("mixed-native-currency-shape")
        }
        if context.snapshot.fundingPlans.isEmpty {
            notObserved("saved-funding-plan-shape")
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func currentMonthSalaryFundingMapsSavedPlanExactlyOrReportsNotObserved() throws {
        let context = try dashboardCurrentDatabaseContext()
        let availability = ApplicationAvailability()
        availability.didHydrate(context.snapshot.hydrationResult, generation: context.provider.generationToken)
        let now = Date()
        let viewModel = DashboardViewModel(
            accountStore: context.accountStore,
            transactionStore: context.transactionStore,
            cardStore: context.cardStore,
            categoryStore: context.categoryStore,
            fundingPlanStore: context.fundingPlanStore,
            availability: availability,
            workspaceID: context.workspaceID,
            now: { now }
        )

        guard let month = DashboardViewModel.currentMonth(at: now),
              let plan = context.snapshot.fundingPlans.first(where: {
                  $0.workspaceID == context.workspaceID && $0.month == month
              }) else {
            check(viewModel.fundingCalculation == nil, "No current-month plan produces no dashboard calculation")
            notObserved("current-month-saved-plan")
            return
        }

        let expected = FundingPlanCalculator.calculate(plan)
        guard let actual = viewModel.fundingCalculation else {
            check(false, "Saved current-month plan produces a dashboard calculation")
            return
        }
        for metric in DashboardFundingMetric.allCases {
            let expectedMoney: Money?
            switch metric {
            case .expected: expectedMoney = expected.expectedNet
            case .indiaShortfall: expectedMoney = expected.indiaFundingShortfall
            case .principal: expectedMoney = expected.requiredQARPrincipal
            case .investment: expectedMoney = expected.availableForInvestment
            }
            check(
                sameMoney(metric.money(in: actual), expectedMoney),
                "Dashboard funding metric maps the accepted saved-plan result"
            )
        }
        check(actual.incompleteReasons == expected.incompleteReasons, "Dashboard funding completeness matches the saved-plan result")
        let expectedState: DashboardContentState = expected.incompleteReasons.contains(.invalidCurrency) ? .unavailable : .populated
        check(viewModel.fundingState == expectedState, "Dashboard funding state preserves complete or missing-input semantics")
        if expected.incompleteReasons.isEmpty {
            notObserved("saved-funding-plan-missing-input-shape")
        }
    }

    @Test
    func fundingMetricLabelsCurrenciesAndNilInputRemainExplicit() {
        for metric in DashboardFundingMetric.allCases {
            let expectedCurrency = metric == .indiaShortfall ? "INR" : "QAR"
            check(metric.currencyCode == expectedCurrency, "Funding metric exposes its accepted native currency")
            check(metric.money(in: nil) == nil, "Funding metric does not fabricate a value without a calculation")
        }
    }

    @Test
    func availabilityAndHydrationStatesCoverLoadingEmptyCurrentUnavailableAndRetained() {
        check(DashboardContentState.resolve(availability: .loading, isEmpty: true) == .loading, "Loading availability remains loading")
        check(DashboardContentState.resolve(availability: .empty, isEmpty: true) == .empty, "Empty availability remains empty")
        check(DashboardContentState.resolve(availability: .empty, isEmpty: false) == .populated, "Nonempty empty-generation data is populated")
        check(DashboardContentState.resolve(availability: .current, isEmpty: true) == .empty, "Current empty data is empty")
        check(DashboardContentState.resolve(availability: .current, isEmpty: false) == .populated, "Current data is populated")
        check(DashboardContentState.resolve(availability: .unavailable, isEmpty: false) == .unavailable, "Unavailable data is unavailable")
        check(DashboardContentState.resolve(availability: .retainedNonCurrent, isEmpty: false) == .unavailable, "Retained noncurrent data is unavailable")

        let availability = ApplicationAvailability()
        let viewModel = DashboardViewModel(
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            cardStore: CardStore(),
            categoryStore: CategoryStore(),
            fundingPlanStore: FundingPlanStore(),
            availability: availability,
            now: { Date(timeIntervalSince1970: 0) }
        )
        viewModel.markHydrationStarted()
        check(viewModel.presentationState == .loading("Loading persisted dashboard..."), "Hydration start is loading")
        check(viewModel.positionState == .loading, "Hydration start resets positions to loading")
        check(viewModel.recentActivityState == .loading, "Hydration start resets activity to loading")
        check(viewModel.fundingState == .loading, "Hydration start resets funding to loading")

        viewModel.markHydrationCompleted(.init(didHydrate: true, accountCount: 1, transactionCount: 2))
        check(viewModel.presentationState == .loaded("Loaded 1 account(s), 2 transaction(s)"), "Hydration completion reports loaded")
        viewModel.markHydrationFailed(DashboardTestError.fixed)
        check(viewModel.presentationState == .failed("Dashboard load failed"), "Hydration failure reports unavailable")
        check(viewModel.positionState == .unavailable, "Hydration failure clears position state")
        check(viewModel.recentActivityState == .unavailable, "Hydration failure clears activity state")
        check(viewModel.fundingState == .unavailable, "Hydration failure clears funding state")
        check(viewModel.positions.isEmpty && viewModel.recentActivity.isEmpty && viewModel.fundingCalculation == nil, "Hydration failure clears projected values")

        availability.didHydrate(.init(didHydrate: true, accountCount: 0, transactionCount: 0), generation: ProviderGenerationToken())
        viewModel.refreshPresentation()
        check(viewModel.fundingState == .unavailable, "A stale funding generation is unavailable rather than an absent saved plan")
    }

    @Test
    func asOfLabelUsesOnlyOptionalStatementDateAndRoutesKeepApprovedDestinations() throws {
        let date = try StatementDate(year: 2026, month: 9, day: 11)
        check(DashboardAccountPosition.asOfLabel(for: date) == "As of \(date.presentation)", "As-of label preserves source day")
        check(DashboardAccountPosition.asOfLabel(for: nil) == "Date unavailable", "Missing as-of date remains unavailable")

        check(DashboardRoute.allCases.count == 3, "Dashboard exposes exactly three approved routes")
        check(DashboardRoute.transactions.destination == .transactions, "Transactions route selects Transactions")
        check(DashboardRoute.imports.destination == .imports, "Import route selects Import")
        check(DashboardRoute.salary.destination == .salary, "Salary route selects Salary")
        check(AppShellSection.ordinaryNavigation.first == .dashboard, "Dashboard remains the default ordinary navigation destination")
    }

    @Test
    func attentionOmitsNonReviewRoutesAndPassesExplicitReviewRoutes() {
        let omitted: [ConfirmedImportRecoveryRoute?] = [
            nil,
            ConfirmedImportRecoveryRoute.none,
            .unavailable,
            .prepareAgain(.persistenceUnavailable),
            .retryCanonicalReconciliation,
            .retryCanonicalReconciliationThenPrepareAgain
        ]
        for route in omitted {
            check(DashboardAttentionProjection.presentation(for: route) == nil, "Non-review import routes are omitted from Dashboard attention")
        }

        let reviewReasons: [ConfirmedImportRecoveryReason] = [
            .validationFailed,
            .exactStatementDuplicate,
            .transactionEventBlock,
            .accountChoiceRequired,
            .accountChoiceStale,
            .identityAmbiguous,
            .identityConflict,
            .identifierOwnershipConflict,
            .repositoryIntegrityConflict
        ]
        for reason in reviewReasons {
            let route: ConfirmedImportRecoveryRoute = .reviewRequired(reason)
            let projected = DashboardAttentionProjection.presentation(for: route)
            let accepted = ConfirmedImportRecoveryPresentationMapper.presentation(for: route)
            check(projected == accepted && projected != nil, "Explicit review-required route passes through unchanged")
            if let projected {
                check(projected.primaryAction == nil, "Review-required attention exposes no mutation action")
            }
        }
    }

    @Test(.globalRuntimeStateIsolation)
    func importActivityUsesHydratedLatestDurableAttemptOrNonfinancialIdleFallback() throws {
        let context = try dashboardCurrentDatabaseContext()
        let latest = ImportActivityPresentation.latestDurableAttempt(from: context.snapshot.importAttempts)
        let expectedLatest = latestImportAttemptOracle(context.snapshot.importAttempts)
        check(latest?.id == expectedLatest?.id, "Import Activity latest durable attempt selection is stable")

        let presentation = ImportActivityPresentation(importState: .idle, latestDurableAttempt: latest)
        if latest == nil {
            check(presentation.title == "No recent import", "Idle Import Activity reports no durable attempt")
            check(presentation.subtitle == "No durable import activity", "Idle Import Activity reports unavailable history")
            check(presentation.status == "Idle", "Idle Import Activity remains idle")
            check(presentation.iconName == "tray", "Idle Import Activity uses the tray icon")
            notObserved("durable-import-attempt")
        } else {
            check(presentation.title == "Latest durable import", "Idle Import Activity uses the latest durable attempt")
            check(!presentation.status.isEmpty && !presentation.subtitle.isEmpty, "Durable Import Activity has bounded presentation fields")
        }
    }

    @Test
    func shellSizingAndRailThresholdRemainDestinationSpecific() {
        check(AppShellSizing.minimumSize(for: .dashboard) == CGSize(width: 640, height: 608), "Dashboard minimum size remains accepted")
        check(AppShellSizing.minimumSize(for: .transactions) == CGSize(width: 1024, height: 736), "Transactions minimum size remains accepted")
        check(AppShellSizing.minimumSize(for: .settings) == CGSize(width: 1180, height: 760), "Other screen minimum size remains accepted")
        check(AppShellSizing.dashboardUsesRail(at: 999), "Dashboard uses rail below the width threshold")
        check(!AppShellSizing.dashboardUsesRail(at: 1000), "Dashboard uses expanded navigation at the width threshold")
    }

    @Test(.globalRuntimeStateIsolation)
    func backgroundCalendarDayNotificationRefreshesThroughMainActorAfterInitialEmissionsDrain() throws {
        let boundaries = try dashboardDayChangeBoundaries()
        guard let beforeMonth = DashboardViewModel.currentMonth(at: boundaries.before),
              let afterMonth = DashboardViewModel.currentMonth(at: boundaries.after) else {
            throw DashboardDayChangeTestError.invalidBoundary
        }
        let probe = DashboardDayChangeProbe(currentDate: boundaries.before)
        let availability = ApplicationAvailability()
        let viewModel = DashboardViewModel(
            accountStore: AccountStore(),
            transactionStore: TransactionStore(),
            cardStore: CardStore(),
            categoryStore: CategoryStore(),
            fundingPlanStore: FundingPlanStore(),
            availability: availability,
            workspaceID: "day-change-regression",
            now: { probe.now() }
        )
        defer { withExtendedLifetime(viewModel) {} }

        try pumpDashboardMainRunLoopUntil(.initialEmissionsDrainedTimeout) {
            probe.refreshCount >= 7
        }
        check(probe.observedMonths.allSatisfy { $0 == beforeMonth }, "Initial store emissions observe the initial month")
        probe.resetObservation()
        probe.advance(to: boundaries.after)

        let postFinished = DispatchGroup()
        postFinished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            dispatchPrecondition(condition: .notOnQueue(.main))
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
            postFinished.leave()
        }

        try pumpDashboardMainRunLoopUntil(.backgroundNotificationTimeout) {
            postFinished.wait(timeout: .now()) == .success && probe.refreshCount > 0
        }
        check(probe.observedMonths.last == afterMonth, "Background calendar notification refreshes the newly applicable month")
    }
}

private enum DashboardTestError: Error {
    case fixed
    case databaseReadFailed
}

private enum DashboardDayChangeTestError: Error {
    case invalidBoundary
    case initialEmissionsDrainedTimeout
    case backgroundNotificationTimeout
}

@MainActor
private final class DashboardDayChangeProbe {
    private(set) var currentDate: Date
    private(set) var observedMonths: [SelectedStatementMonth] = []

    init(currentDate: Date) {
        self.currentDate = currentDate
    }

    func now() -> Date {
        MainActor.assertIsolated()
        if let month = DashboardViewModel.currentMonth(at: currentDate) {
            observedMonths.append(month)
        }
        return currentDate
    }

    var refreshCount: Int { observedMonths.count }

    func resetObservation() {
        observedMonths.removeAll()
    }

    func advance(to date: Date) {
        currentDate = date
    }
}

@MainActor
private func dashboardDayChangeBoundaries() throws -> (before: Date, after: Date) {
    let calendar = Calendar(identifier: .gregorian)
    guard let before = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)),
          let after = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 12)),
          DashboardViewModel.currentMonth(at: before) != DashboardViewModel.currentMonth(at: after) else {
        throw DashboardDayChangeTestError.invalidBoundary
    }
    return (before, after)
}

@MainActor
private func pumpDashboardMainRunLoopUntil(
    _ timeout: DashboardDayChangeTestError,
    condition: () -> Bool
) throws {
    let deadline = Date(timeIntervalSinceNow: 2)
    while !condition() {
        guard Date() < deadline else { throw timeout }
        _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
    }
}

private struct DashboardReadOnlyContext {
    let provider: SQLiteRepositoryProvider
    let databaseURL: URL
    let workspaceID: String
    let snapshot: RepositoryRuntimeSnapshot
    let accountStore: AccountStore
    let transactionStore: TransactionStore
    let cardStore: CardStore
    let categoryStore: CategoryStore
    let salaryStore: SalaryStore
    let fundingPlanStore: FundingPlanStore
    let importSessionStore: ImportSessionStore
}

@MainActor
private enum AcceptedDashboardSnapshot {
    static var cached: DashboardReadOnlyContext?
}

@MainActor
private func dashboardCurrentDatabaseContext() throws -> DashboardReadOnlyContext {
    if let cached = AcceptedDashboardSnapshot.cached { return cached }

    let identity = try DevelopmentDatabaseIdentity.applicationOwned(environment: ProcessInfo.processInfo.environment)
    let databaseURL = identity.canonicalDevelopmentURL
    guard !identity.isIsolatedCanonicalNamespace,
          identity.authorizesCurrentDatabaseIdentity(at: databaseURL),
          FileManager.default.fileExists(atPath: databaseURL.path) else {
        throw RepositoryError.persistenceUnavailable
    }

    let provider = try SQLiteRepositoryProvider(path: databaseURL.absoluteString + "?mode=ro")
    try provider.database.execute(sql: "PRAGMA query_only = ON;")
    let workspaces = try provider.database.query(sql: "SELECT id FROM workspaces ORDER BY id", params: []) {
        $0.string(at: 0)
    }.compactMap { $0 }
    guard workspaces.count == 1, let workspaceID = workspaces.first else {
        throw RepositoryError.persistenceUnavailable
    }

    let accountStore = AccountStore()
    let transactionStore = TransactionStore()
    let cardStore = CardStore()
    let categoryStore = CategoryStore()
    let salaryStore = SalaryStore()
    let fundingPlanStore = FundingPlanStore()
    let importSessionStore = ImportSessionStore()
    let hydrator = RepositoryStoreHydrator(
        accountRepo: provider.accountRepo,
        importSessionRepo: provider.importSessionRepo,
        transactionRepo: provider.transactionRepo,
        categoryRepo: provider.categoryRepo,
        cardRepo: provider.cardRepo,
        salaryRepo: provider.salaryRepo,
        fundingPlanRepo: provider.fundingPlanRepo,
        accountStore: accountStore,
        transactionStore: transactionStore,
        categoryStore: categoryStore,
        cardStore: cardStore,
        salaryStore: salaryStore,
        fundingPlanStore: fundingPlanStore,
        importSessionStore: importSessionStore,
        importAttemptStore: ImportAttemptStore(),
        workspaceId: workspaceID,
        persistenceState: .verifiedSQLite,
        providerGeneration: provider.generationToken,
        participatesInLifecycleGate: false
    )
    let snapshot = try hydrator.stageHydration()
    hydrator.publish(snapshot)
    let context = DashboardReadOnlyContext(
        provider: provider,
        databaseURL: databaseURL,
        workspaceID: workspaceID,
        snapshot: snapshot,
        accountStore: accountStore,
        transactionStore: transactionStore,
        cardStore: cardStore,
        categoryStore: categoryStore,
        salaryStore: salaryStore,
        fundingPlanStore: fundingPlanStore,
        importSessionStore: importSessionStore
    )
    AcceptedDashboardSnapshot.cached = context
    return context
}

private struct DatabaseFiles: Equatable {
    let database: Data?
    let wal: Data?
}

@MainActor
private func databaseFiles(_ context: DashboardReadOnlyContext) throws -> DatabaseFiles {
    guard let database = try? Data(contentsOf: context.databaseURL) else {
        throw DashboardTestError.databaseReadFailed
    }
    let walURL = URL(fileURLWithPath: context.databaseURL.path + "-wal")
    let wal: Data?
    if FileManager.default.fileExists(atPath: walURL.path) {
        guard let value = try? Data(contentsOf: walURL) else {
            throw DashboardTestError.databaseReadFailed
        }
        wal = value
    } else {
        wal = nil
    }
    return DatabaseFiles(database: database, wal: wal)
}

private struct OraclePosition {
    let id: String
    let displayName: String
    let institution: String
    let amount: Money?
    let asOf: StatementDate?
    let sourceContext: String?
}

private struct OracleCurrencyPosition {
    let currency: CurrencyCode
    let banks: [OraclePosition]
    let cards: [OraclePosition]
    let bankTotal: Money?
    let cardTotal: Money?
}

@MainActor
private func dashboardPositionOracle(snapshot: RepositoryRuntimeSnapshot) -> [OracleCurrencyPosition] {
    let eligible = snapshot.accounts
        .filter { $0.type == .bank || $0.type == .creditCard }
        .sorted(by: oracleAccountPrecedes)
    let banks = eligible.compactMap { account -> (CurrencyCode, OraclePosition)? in
        guard account.type == .bank else { return nil }
        let selected = oracleBankBalance(for: account, transactions: snapshot.transactions)
        let amount = selected?.money.currency == account.nativeCurrency ? selected?.money : nil
        return (
            account.nativeCurrency,
            OraclePosition(
                id: oraclePositionID(account),
                displayName: account.nickname ?? account.name,
                institution: account.institution,
                amount: amount,
                asOf: amount == nil ? nil : selected?.date,
                sourceContext: nil
            )
        )
    }
    let cards = eligible.compactMap { account -> (CurrencyCode, OraclePosition)? in
        guard account.type == .creditCard else { return nil }
        let selected = oracleCardStatement(for: account, snapshot: snapshot.cardSnapshot)
        let amount: Money?
        if let selected,
           let newBalance = selected.newBalance,
           selected.currency == account.nativeCurrency,
           newBalance.currency == account.nativeCurrency {
            amount = newBalance
        } else {
            amount = nil
        }
        return (
            account.nativeCurrency,
            OraclePosition(
                id: oraclePositionID(account),
                displayName: account.nickname ?? account.name,
                institution: account.institution,
                amount: amount,
                asOf: amount == nil ? nil : selected?.statementDate,
                sourceContext: amount == nil || selected?.statementDate != nil
                    ? nil
                    : oracleCardSourceContext(selected)
            )
        )
    }

    let currencies = Set(banks.map(\.0)).union(cards.map(\.0)).sorted { $0.code < $1.code }
    return currencies.map { currency in
        let bankPositions = banks.filter { $0.0 == currency }.map(\.1)
        let cardPositions = cards.filter { $0.0 == currency }.map(\.1)
        return OracleCurrencyPosition(
            currency: currency,
            banks: bankPositions,
            cards: cardPositions,
            bankTotal: oracleAggregate(bankPositions, currency: currency),
            cardTotal: oracleAggregate(cardPositions, currency: currency)
        )
    }
}

@MainActor
private func oraclePositionID(_ account: Account) -> String {
    account.repositoryAccountId ?? account.id.uuidString
}

@MainActor
private func oracleAccountPrecedes(_ lhs: Account, _ rhs: Account) -> Bool {
    let left = (lhs.institution, lhs.nickname ?? lhs.name, oraclePositionID(lhs))
    let right = (rhs.institution, rhs.nickname ?? rhs.name, oraclePositionID(rhs))
    if left.0 != right.0 { return left.0 < right.0 }
    if left.1 != right.1 { return left.1 < right.1 }
    return left.2 < right.2
}

@MainActor
private func oracleAggregate(_ positions: [OraclePosition], currency: CurrencyCode) -> Money? {
    guard !positions.isEmpty, positions.allSatisfy({ $0.amount?.currency == currency }) else { return nil }
    return try? Money.aggregate(positions.compactMap(\.amount))
}

@MainActor
private func oracleBankBalance(
    for account: Account,
    transactions: [Transaction]
) -> (money: Money, date: StatementDate)? {
    guard let accountID = account.repositoryAccountId else { return nil }
    let dated = transactions.compactMap { transaction -> (transaction: Transaction, money: Money, date: StatementDate)? in
        guard transaction.repositoryAccountId == accountID,
              let date = transaction.statementDate,
              let money = transaction.runningBalanceMoney else { return nil }
        return (transaction, money, date)
    }
    guard let latestDate = dated.map(\.date).max() else { return nil }
    let candidates = dated.filter { $0.date == latestDate }
    let selected: (transaction: Transaction, money: Money, date: StatementDate)?
    if let documentID = candidates.first?.transaction.documentScopedSourceOrder?.documentID,
       candidates.allSatisfy({ $0.transaction.documentScopedSourceOrder?.documentID == documentID }) {
        selected = candidates.max {
            ($0.transaction.documentScopedSourceOrder?.ordinal ?? 0)
                < ($1.transaction.documentScopedSourceOrder?.ordinal ?? 0)
        }
    } else {
        selected = candidates.count == 1 ? candidates.first : nil
    }
    guard let selected, selected.money.currency == account.nativeCurrency else { return nil }
    return (selected.money, selected.date)
}

@MainActor
private func oracleCardStatement(for account: Account, snapshot: CardStoreSnapshot) -> CardStatement? {
    guard let accountID = account.repositoryAccountId else { return nil }
    let statements = snapshot.statements.filter { $0.liabilityAccountID == accountID }
    if statements.allSatisfy({ !$0.parserProfileID.hasPrefix("axis.credit-card.") }) {
        return statements.max { lhs, rhs in
            let leftDate = lhs.statementDate?.canonical ?? ""
            let rightDate = rhs.statementDate?.canonical ?? ""
            if leftDate != rightDate { return leftDate < rightDate }
            let leftEnd = lhs.period?.end.canonical ?? ""
            let rightEnd = rhs.period?.end.canonical ?? ""
            if leftEnd != rightEnd { return leftEnd < rightEnd }
            return lhs.id < rhs.id
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
        return exact.count == 1 || (groupIDs.count == 1 && exact.allSatisfy { $0.semanticGroupID != nil })
            ? exact.first
            : nil
    }
    let groupIDs = Set(cycle.compactMap(\.semanticGroupID))
    return cycle.count == 1 || (groupIDs.count == 1 && cycle.allSatisfy { $0.semanticGroupID != nil })
        ? cycle.first
        : nil
}

@MainActor
private func oracleCardSourceContext(_ statement: CardStatement?) -> String? {
    guard let statement else { return nil }
    if let period = statement.period {
        return "Statement period \(period.start.presentation)–\(period.end.presentation)"
    }
    if let month = statement.selectedStatementMonth {
        return "Statement month \(month.canonical)"
    }
    return nil
}

@MainActor
private func assertPositions(_ actual: [DashboardCurrencyPosition], equalTo expected: [OracleCurrencyPosition]) {
    check(actual.count == expected.count, "Dashboard currency-group count matches independent oracle")
    for (actualGroup, expectedGroup) in zip(actual, expected) {
        check(actualGroup.currency == expectedGroup.currency, "Dashboard currency group preserves native currency")
        assertAccountPositions(actualGroup.banks, equalTo: expectedGroup.banks)
        assertAccountPositions(actualGroup.cards, equalTo: expectedGroup.cards)
        check(sameMoney(actualGroup.bankTotal, expectedGroup.bankTotal), "Dashboard bank total sums only known same-currency members")
        check(sameMoney(actualGroup.cardTotal, expectedGroup.cardTotal), "Dashboard card total sums only known same-currency members")
    }
}

@MainActor
private func assertAccountPositions(_ actual: [DashboardAccountPosition], equalTo expected: [OraclePosition]) {
    check(actual.count == expected.count, "Dashboard account membership matches independent domain oracle")
    for (actualPosition, expectedPosition) in zip(actual, expected) {
        check(actualPosition.id == expectedPosition.id, "Dashboard account identity is durable")
        check(actualPosition.displayName == expectedPosition.displayName, "Dashboard account display name is canonical")
        check(actualPosition.institution == expectedPosition.institution, "Dashboard account institution is canonical")
        check(sameMoney(actualPosition.amount, expectedPosition.amount), "Dashboard account amount matches selected source money")
        check(actualPosition.asOf == expectedPosition.asOf, "Dashboard account as-of date is source-backed")
        check(actualPosition.sourceContext == expectedPosition.sourceContext, "Dashboard account source context remains optional")
    }
}

@MainActor
private func assertCanonicalBalancesMatchSelectedEvidence(snapshot: RepositoryRuntimeSnapshot) {
    for account in snapshot.accounts where account.type == .bank {
        guard let selected = oracleBankBalance(for: account, transactions: snapshot.transactions) else { continue }
        check(sameMoney(account.currentBalanceMoney, selected.money), "Hydrated bank balance matches selected running balance")
    }
    for account in snapshot.accounts where account.type == .creditCard {
        guard let selected = oracleCardStatement(for: account, snapshot: snapshot.cardSnapshot),
              let newBalance = selected.newBalance else { continue }
        guard let negated = try? Money(amount: -newBalance.amount, currency: newBalance.currency) else {
            check(false, "Hydrated card balance can be compared with selected statement balance")
            continue
        }
        check(sameMoney(account.currentBalanceMoney, negated), "Hydrated card balance is the negation of selected statement balance")
    }
}

private struct OracleRecentActivityRow {
    let transaction: Transaction
    let stableID: String
    let accountID: String?
    let accountDisplayName: String
    let accountIdentityDisplay: String
    let institutionDisplayName: String
    let currentCategory: TransactionPresentationCategoryChoice
    let currentCategoryDisplayName: String
    let domain: TransactionPresentationDomain
    let effect: TransactionPresentationEffect
    let sourceCivilDate: StatementDate?
}

@MainActor
private func recentActivityOracle(snapshot: RepositoryRuntimeSnapshot) -> [OracleRecentActivityRow] {
    let accounts = Dictionary(uniqueKeysWithValues: snapshot.accounts.compactMap { account in
        account.repositoryAccountId.map { ($0, account) }
    })
    let categories = Dictionary(uniqueKeysWithValues: snapshot.categorySnapshot.categories.map { ($0.id, $0) })
    return Array(snapshot.transactions.map { transaction in
        let account = transaction.repositoryAccountId.flatMap { accounts[$0] }
        let categoryID = transaction.repositoryTransactionId.flatMap { snapshot.categorySnapshot.assignments[$0] }
        let category = categoryID.flatMap { categories[$0] }
        let domain: TransactionPresentationDomain
        if transaction.cardLiabilityEffect != nil || account?.type == .creditCard {
            domain = .card
        } else if account?.type == .bank {
            domain = .bank
        } else {
            domain = .unknown
        }
        let effect: TransactionPresentationEffect
        switch domain {
        case .card:
            switch transaction.cardLiabilityEffect {
            case .increasesAmountOwed: effect = .increasesAmountOwed
            case .decreasesAmountOwed: effect = .decreasesAmountOwed
            case nil: effect = .unknown
            }
        case .bank:
            if transaction.creditMoney != nil, transaction.debitMoney == nil { effect = .credit }
            else if transaction.debitMoney != nil, transaction.creditMoney == nil { effect = .debit }
            else { effect = .unknown }
        case .unknown:
            effect = .unknown
        }
        return OracleRecentActivityRow(
            transaction: transaction,
            stableID: oracleStableID(transaction),
            accountID: transaction.repositoryAccountId,
            accountDisplayName: account?.name ?? "Unavailable",
            accountIdentityDisplay: account?.identitySummaries.map(\.redactedValue).sorted().joined(separator: ", ") ?? "",
            institutionDisplayName: account?.institution ?? "Unavailable",
            currentCategory: categoryID.map(TransactionPresentationCategoryChoice.categoryID) ?? .uncategorized,
            currentCategoryDisplayName: categoryID == nil ? "Uncategorized" : (category?.name ?? "Unavailable"),
            domain: domain,
            effect: effect,
            sourceCivilDate: transaction.statementDate
        )
    }.sorted(by: oracleRecentActivityPrecedes).prefix(3))
}

@MainActor
private func oracleStableID(_ transaction: Transaction) -> String {
    if let durable = transaction.repositoryTransactionId, !durable.isEmpty {
        return "durable:" + durable
    }
    return "runtime:" + transaction.id.uuidString.lowercased()
}

@MainActor
private func oracleRecentActivityPrecedes(_ lhs: OracleRecentActivityRow, _ rhs: OracleRecentActivityRow) -> Bool {
    switch (lhs.sourceCivilDate, rhs.sourceCivilDate) {
    case let (left?, right?) where left != right:
        return left > right
    case (.some, nil):
        return true
    case (nil, .some):
        return false
    default:
        break
    }
    let leftSource = lhs.transaction.documentScopedSourceOrder
    let rightSource = rhs.transaction.documentScopedSourceOrder
    if let leftSource, let rightSource,
       leftSource.documentID == rightSource.documentID,
       leftSource.ordinal != rightSource.ordinal {
        return leftSource.ordinal < rightSource.ordinal
    }
    let leftDocument = lhs.transaction.repositoryDocumentId ?? leftSource?.documentID ?? ""
    let rightDocument = rhs.transaction.repositoryDocumentId ?? rightSource?.documentID ?? ""
    if leftDocument != rightDocument { return leftDocument < rightDocument }
    return lhs.stableID < rhs.stableID
}

@MainActor
private func assertRecentActivity(_ actual: [TransactionPresentationRow], equalTo expected: [OracleRecentActivityRow]) {
    check(actual.count == expected.count, "Dashboard recent activity count matches independent oracle")
    for (actualRow, expectedRow) in zip(actual, expected) {
        check(actualRow.stableID == expectedRow.stableID, "Dashboard recent activity stable identity is durable or runtime scoped")
        check(actualRow.transaction.id == expectedRow.transaction.id, "Dashboard recent activity retains transaction identity")
        check(sameMoney(actualRow.transaction.money, expectedRow.transaction.money), "Dashboard recent activity retains native Money")
        check(actualRow.accountID == expectedRow.accountID, "Dashboard recent activity account identity is canonical")
        check(actualRow.accountDisplayName == expectedRow.accountDisplayName, "Dashboard recent activity account display is canonical")
        check(actualRow.accountIdentityDisplay == expectedRow.accountIdentityDisplay, "Dashboard recent activity identity display is canonical")
        check(actualRow.institutionDisplayName == expectedRow.institutionDisplayName, "Dashboard recent activity institution is canonical")
        check(actualRow.currentCategory == expectedRow.currentCategory, "Dashboard recent activity category choice is canonical")
        check(actualRow.currentCategoryDisplayName == expectedRow.currentCategoryDisplayName, "Dashboard recent activity category display is canonical")
        check(actualRow.domain == expectedRow.domain, "Dashboard recent activity domain is canonical")
        check(actualRow.effect == expectedRow.effect, "Dashboard recent activity effect is canonical")
        check(actualRow.sourceCivilDate == expectedRow.sourceCivilDate, "Dashboard recent activity date is source-backed")
    }
}

@MainActor
private func latestImportAttemptOracle(_ attempts: [RepositoryImportAttempt]) -> RepositoryImportAttempt? {
    attempts.max { lhs, rhs in
        switch (importAttemptDate(lhs.createdAtISO), importAttemptDate(rhs.createdAtISO)) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, nil):
            return false
        case (nil, .some):
            return true
        default:
            return lhs.id < rhs.id
        }
    }
}

@MainActor
private func importAttemptDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
}

@MainActor
private func sameMoney(_ lhs: Money?, _ rhs: Money?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil): return true
    case let (left?, right?): return left.currency == right.currency && left.amount == right.amount
    default: return false
    }
}

@MainActor
private func check(_ condition: Bool, _ label: String) {
    #expect(condition, "\(label)")
}

@MainActor
private func notObserved(_ caseName: String) {
    print("NOT_OBSERVED \(caseName)")
}
