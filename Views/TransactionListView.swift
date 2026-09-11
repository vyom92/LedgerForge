//
//  TransactionListView.swift
//  LedgerForge
//

import SwiftUI
import AppKit

private struct TransactionCategoryMutationIntent {
    let categoryID: String?
    let transactionID: String
#if DEBUG
    var protectedAction: DevelopmentProtectedAction {
        categoryID == nil ? .transactionCategoryClear : .transactionCategoryAssignment
    }
#endif
}

/// Native Table owns column interaction; the model owns the financial presentation order.
private struct TransactionTableComparator: SortComparator {
    var key: TransactionPresentationSortKey
    var order: SortOrder = .forward

    func compare(_ lhs: TransactionPresentationRow, _ rhs: TransactionPresentationRow) -> ComparisonResult {
        TransactionPresentationEngine.comparison(
            lhs, rhs, sort: .init(key: key, direction: order == .forward ? .ascending : .descending)
        )
    }
}

enum TransactionPeriodChoice: String, CaseIterable {
    case all = "All dates"
    case thisMonth = "This month"
    case lastMonth = "Last month"
    case yearToDate = "Year to date"
    case custom = "Custom range"

    func range(relativeTo today: StatementDate) throws -> TransactionPresentationStatementDateRange? {
        func lastDay(year: Int, month: Int) throws -> StatementDate {
            for day in stride(from: 31, through: 28, by: -1) {
                if let date = try? StatementDate(year: year, month: month, day: day) { return date }
            }
            throw StatementDate.Error.invalidComponents(year: year, month: month, day: 1)
        }
        switch self {
        case .all, .custom:
            return nil
        case .thisMonth:
            return try .init(
                start: StatementDate(year: today.year, month: today.month, day: 1),
                end: lastDay(year: today.year, month: today.month)
            )
        case .lastMonth:
            let year = today.month == 1 ? today.year - 1 : today.year
            let month = today.month == 1 ? 12 : today.month - 1
            return try .init(start: StatementDate(year: year, month: month, day: 1), end: lastDay(year: year, month: month))
        case .yearToDate:
            return try .init(start: StatementDate(year: today.year, month: 1, day: 1), end: today)
        }
    }
}

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()
    @ObservedObject private var categoryStore: CategoryStore
    private let categoryCoordinator: CategoryManaging
    private let generation: ProviderGenerationToken?
    private let availabilityState: ApplicationDataState
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif
    @State private var detailsVisible = true
    @State private var narrowDetailsVisible = false
    @State private var moreFiltersVisible = false
    @State private var period: TransactionPeriodChoice = .all
    @State private var customStart = ""
    @State private var customEnd = ""
    @State private var minimumAmount = ""
    @State private var maximumAmount = ""
    @State private var amountInputError: String?
    @State private var dateInputError: String?
    @State private var categoryMessage: String?
    @State private var categoryReconciliationRequired = false
    @FocusState private var searchFocused: Bool
    @FocusState private var tableFocused: Bool
#if DEBUG
    @State private var pendingCategoryMutation: TransactionCategoryMutationIntent?
    @State private var acknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
#endif

    private let secondary = Color(hex: 0xABB7C9)
    private let panelColor = Color(hex: 0x111827)
    private let controlBorder = Color(hex: 0x77869C)
    private let focusColor = Color(hex: 0xB2A3FF)

#if DEBUG
    @MainActor
    init(
        generation: ProviderGenerationToken? = nil,
        availabilityState: ApplicationDataState = .loading,
        categoryStore: CategoryStore? = nil,
        categoryCoordinator: CategoryManaging? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self.categoryStore = resolvedStore
        self.categoryCoordinator = categoryCoordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
        self.acknowledgementGate = acknowledgementGate ?? .shared
        self.generation = generation
        self.availabilityState = availabilityState
    }
#else
    @MainActor
    init(
        generation: ProviderGenerationToken? = nil,
        availabilityState: ApplicationDataState = .loading,
        categoryStore: CategoryStore? = nil,
        categoryCoordinator: CategoryManaging? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self.categoryStore = resolvedStore
        self.categoryCoordinator = categoryCoordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
        self.generation = generation
        self.availabilityState = availabilityState
    }
#endif

    private var result: TransactionPresentationResult { viewModel.transactionPresentationResult }
    private var selectedTransaction: Transaction? { viewModel.selectedPresentationRow?.transaction }
    private var inputError: String? { dateInputError ?? amountInputError }
    private var hasUsableResults: Bool { inputError == nil && result.state == .ready }
    private var selection: Binding<String?> {
        Binding(get: { viewModel.selectedPresentationRowID }, set: { viewModel.selectPresentationRow(id: $0) })
    }
    private var tableSort: Binding<[TransactionTableComparator]> {
        Binding(
            get: { [.init(key: viewModel.presentationSort.key, order: viewModel.presentationSort.direction == .ascending ? .forward : .reverse)] },
            set: { comparators in
                guard let first = comparators.first else { return }
                viewModel.presentationSort = .init(key: first.key, direction: first.order == .forward ? .ascending : .descending)
            }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let narrow = geometry.size.width < 1120
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    searchAndPeriod(narrow: narrow)
                    primaryFilters
                    if period == .custom { customDateControls }
                    matchingSummary
                    transactionTable
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                if !narrow && detailsVisible {
                    inspector
                        .frame(width: 320)
                }
            }
            .padding(24)
            .onChange(of: narrow, initial: true) { _, constrained in
                if constrained { detailsVisible = false }
            }
            .sheet(isPresented: $narrowDetailsVisible) {
                inspector
                    .padding(16)
                    .frame(width: 400, height: 580)
                    .background(panelColor)
            }
        }
        .background(LFTheme.backgroundGradient)
        .foregroundStyle(LFTheme.text)
        .font(.system(size: 14))
        .onAppear(perform: synchronizePresentation)
        .onChange(of: generation) { _, _ in synchronizePresentation() }
        .onChange(of: availabilityState) { _, _ in synchronizePresentation() }
        .onChange(of: period) { _, _ in updatePeriod() }
        .onChange(of: customStart) { _, _ in updatePeriod() }
        .onChange(of: customEnd) { _, _ in updatePeriod() }
        .onChange(of: minimumAmount) { _, _ in updateAmount() }
        .onChange(of: maximumAmount) { _, _ in updateAmount() }
        .onChange(of: inputError) { _, newValue in
            if newValue != nil { viewModel.selectPresentationRow(id: nil) }
        }
#if DEBUG
        .confirmationDialog(
            DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(
                get: { acknowledgementChallenge != nil && pendingCategoryMutation != nil },
                set: { if !$0 { cancelDevelopmentProfileAcknowledgement() } }
            ),
            titleVisibility: .visible
        ) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                approveDevelopmentProfileAcknowledgement()
            }
            Button("Cancel", role: .cancel) { cancelDevelopmentProfileAcknowledgement() }
        } message: {
            Text(DevelopmentProfileAcknowledgementPresentation.message)
        }
#endif
    }

    private func synchronizePresentation() {
        viewModel.synchronizePresentation(generation: generation, availabilityState: availabilityState)
    }

    private func searchAndPeriod(narrow: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(secondary)
                TextField("Search transactions", text: $viewModel.presentationFilter.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityLabel("Search transactions")
                    .help("Every word must match a displayed description, account, institution, or current category.")
                if !viewModel.presentationFilter.searchText.isEmpty {
                    Button {
                        viewModel.presentationFilter.searchText = ""
                        searchFocused = true
                    } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(panelColor, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(searchFocused ? focusColor : controlBorder, lineWidth: searchFocused ? 2 : 1))

            Picker("Period", selection: $period) {
                ForEach(TransactionPeriodChoice.allCases, id: \.self) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .labelsHidden()
            .frame(width: 150)
            .help("Filter by the date printed on each transaction.")

            Button {
                if narrow { narrowDetailsVisible = true }
                else { detailsVisible.toggle() }
            } label: {
                Label(!narrow && detailsVisible ? "Hide details" : "Show details", systemImage: "sidebar.right")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(!narrow && detailsVisible ? "Hide details" : "Show details")
            .help("Open or close details without changing the selected transaction.")
        }
        .controlSize(.large)
    }

    private var primaryFilters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    accountMenu
                    currencyMenu
                    categoryMenu
                    familyMenu
                    effectMenu
                    moreFiltersButton
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    accountMenu
                    currencyMenu
                    categoryMenu
                    moreFiltersButton
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 12) {
                Text(activeCriteriaCount == 0 ? "All transactions · source dates · native currencies" : "\(activeCriteriaCount) active criteria · all matching transactions")
                    .font(.system(size: 12))
                    .foregroundStyle(secondary)
                Spacer(minLength: 0)
                Button("Clear filters", action: clearFilters)
                    .buttonStyle(.borderless)
                    .disabled(activeCriteriaCount == 0)
            }
        }
    }

    private var accountOptions: [(id: String, name: String)] {
        var accounts = [String: TransactionPresentationRow]()
        for row in viewModel.allPresentationRows {
            if let id = row.accountID { accounts[id] = row }
        }
        let nameCounts = Dictionary(grouping: accounts.values) {
            TransactionPresentationText.normalized($0.accountDisplayName)
        }.mapValues(\.count)
        return accounts.map { id, row in
            let hasCollision = nameCounts[TransactionPresentationText.normalized(row.accountDisplayName), default: 0] > 1
            let label = hasCollision
                ? [row.accountDisplayName, row.institutionDisplayName, row.transaction.money.currency.code, row.accountIdentityDisplay]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                : row.accountDisplayName
            return (id: id, name: label)
        }.sorted {
            let left = TransactionPresentationText.normalized($0.name)
            let right = TransactionPresentationText.normalized($1.name)
            return left == right ? $0.id < $1.id : left < right
        }
    }
    private var currencyOptions: [CurrencyCode] {
        Set(viewModel.allPresentationRows.map { $0.transaction.money.currency }).sorted { $0.code < $1.code }
    }
    private var institutionOptions: [String] {
        Set(viewModel.allPresentationRows.filter { $0.accountID != nil }.map(\.institutionDisplayName))
            .sorted { TransactionPresentationText.normalized($0) < TransactionPresentationText.normalized($1) }
    }
    private var categoryOptions: [Category] {
        categoryStore.snapshot.categories.sorted { $0.normalizedName == $1.normalizedName ? $0.id < $1.id : $0.normalizedName < $1.normalizedName }
    }

    private var accountMenu: some View {
        Menu {
            Button("All accounts") { viewModel.presentationFilter.accountIDs = [] }
            Divider()
            ForEach(accountOptions, id: \.id) { option in
                Toggle(option.name, isOn: membership(\.accountIDs, option.id))
            }
        } label: { filterLabel("Account", count: viewModel.presentationFilter.accountIDs.count) }
        .help("Choose one or more accounts. Accounts keep their durable identity.")
    }
    private var currencyMenu: some View {
        Menu {
            Button("All currencies") { viewModel.presentationFilter.currencies = [] }
            Divider()
            ForEach(currencyOptions, id: \.self) { currency in
                Toggle(currency.code, isOn: membership(\.currencies, currency))
            }
        } label: { filterLabel("Currency", count: viewModel.presentationFilter.currencies.count) }
    }
    private var categoryMenu: some View {
        Menu {
            Button("All categories") { viewModel.presentationFilter.categories = [] }
            Divider()
            Toggle("Uncategorized", isOn: membership(\.categories, .uncategorized))
            ForEach(categoryOptions) { category in
                Toggle(category.isArchived ? "\(category.name) (Archived)" : category.name,
                       isOn: membership(\.categories, .categoryID(category.id)))
            }
        } label: { filterLabel("Category", count: viewModel.presentationFilter.categories.count) }
    }
    private var familyMenu: some View {
        Menu {
            Button("All families") { viewModel.presentationFilter.domains = [] }
            Divider()
            Toggle("Bank", isOn: membership(\.domains, .bank))
            Toggle("Card", isOn: membership(\.domains, .card))
        } label: { filterLabel("Family", count: viewModel.presentationFilter.domains.count) }
    }
    private var effectMenu: some View {
        Menu {
            Button("All effects") { viewModel.presentationFilter.effects = [] }
            Divider()
            Toggle("Bank credit", isOn: membership(\.effects, .credit))
            Toggle("Bank debit", isOn: membership(\.effects, .debit))
            Toggle("Card increase owed", isOn: membership(\.effects, .increasesAmountOwed))
            Toggle("Card decrease owed", isOn: membership(\.effects, .decreasesAmountOwed))
        } label: { filterLabel("Effect", count: viewModel.presentationFilter.effects.count) }
    }
    private var institutionMenu: some View {
        Menu {
            Button("All institutions") { viewModel.presentationFilter.institutionDisplayNames = [] }
            Divider()
            ForEach(institutionOptions, id: \.self) { institution in
                Toggle(institution, isOn: membership(\.institutionDisplayNames, institution))
            }
        } label: { filterLabel("Institution", count: viewModel.presentationFilter.institutionDisplayNames.count) }
    }
    private var moreFiltersButton: some View {
        Button {
            moreFiltersVisible.toggle()
        } label: { Label("More filters", systemImage: "line.3.horizontal.decrease") }
            .buttonStyle(.bordered)
            .accessibilityLabel("More filters")
            .popover(isPresented: $moreFiltersVisible, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("More filters").font(.headline)
                    HStack { familyMenu; effectMenu }
                    institutionMenu
                    Divider()
                    Text("Amount range").font(.headline)
                    Text("Choose one native currency. Bounds include the entered amounts.")
                        .font(.system(size: 12)).foregroundStyle(secondary)
                    currencyMenu
                    HStack {
                        TextField("Minimum", text: $minimumAmount)
                            .accessibilityLabel("Minimum native amount")
                        TextField("Maximum", text: $maximumAmount)
                            .accessibilityLabel("Maximum native amount")
                    }
                    .textFieldStyle(.roundedBorder)
                    Text("Use a decimal point; leave a bound empty for no limit.")
                        .font(.system(size: 12)).foregroundStyle(secondary)
                    if let message = amountInputError {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(LFTheme.warning)
                    } else if viewModel.presentationFilter.amountRange != nil && viewModel.presentationFilter.currencies.count != 1 {
                        Text("Select exactly one currency to apply an amount range.")
                            .foregroundStyle(LFTheme.warning)
                    }
                    HStack {
                        Button("Clear amount") { minimumAmount = ""; maximumAmount = ""; updateAmount() }
                        Spacer()
                        Button("Done") { moreFiltersVisible = false }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
                .frame(width: 400)
            }
    }

    private func filterLabel(_ title: String, count: Int) -> some View {
        Text(count == 0 ? "\(title): All" : "\(title): \(count)")
            .font(.system(size: 13))
            .padding(.vertical, 3)
    }

    private func membership<Value: Hashable>(
        _ keyPath: WritableKeyPath<TransactionPresentationFilterSpec, Set<Value>>,
        _ value: Value
    ) -> Binding<Bool> {
        Binding(
            get: { viewModel.presentationFilter[keyPath: keyPath].contains(value) },
            set: { enabled in
                var filter = viewModel.presentationFilter
                if enabled { filter[keyPath: keyPath].insert(value) }
                else { filter[keyPath: keyPath].remove(value) }
                viewModel.presentationFilter = filter
            }
        )
    }

    private var activeCriteriaCount: Int {
        let filter = viewModel.presentationFilter
        return [
            !TransactionPresentationText.normalized(filter.searchText).isEmpty,
            !filter.accountIDs.isEmpty, !filter.currencies.isEmpty, !filter.categories.isEmpty,
            !filter.domains.isEmpty, !filter.effects.isEmpty, !filter.institutionDisplayNames.isEmpty,
            !minimumAmount.isEmpty || !maximumAmount.isEmpty, period != .all
        ].filter { $0 }.count
    }

    private var customDateControls: some View {
        HStack(spacing: 12) {
            Text("Source date").foregroundStyle(secondary)
            TextField("From YYYY-MM-DD", text: $customStart)
                .accessibilityLabel("Source date from, year month day")
            Text("to").foregroundStyle(secondary)
            TextField("Through YYYY-MM-DD", text: $customEnd)
                .accessibilityLabel("Source date through, year month day")
            Text("Inclusive").font(.system(size: 12)).foregroundStyle(secondary)
        }
        .textFieldStyle(.roundedBorder)
    }

    private func updatePeriod() {
        dateInputError = nil
        if period == .all { viewModel.presentationFilter.statementDateRange = nil; return }
        if period == .custom {
            do {
                let start = customStart.isEmpty ? nil : try StatementDate(canonical: customStart)
                let end = customEnd.isEmpty ? nil : try StatementDate(canonical: customEnd)
                guard start != nil || end != nil else {
                    dateInputError = "Enter at least one source date in YYYY-MM-DD format."
                    return
                }
                viewModel.presentationFilter.statementDateRange = .init(start: start, end: end)
            } catch {
                dateInputError = "Use a valid source date in YYYY-MM-DD format."
            }
            return
        }
        // Only today's user-facing calendar is converted to components.
        // Imported StatementDate values remain civil dates throughout evaluation.
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        guard let year = today.year, let month = today.month, let day = today.day else {
            dateInputError = "The current calendar date is unavailable."; return
        }
        do {
            viewModel.presentationFilter.statementDateRange = try period.range(
                relativeTo: StatementDate(year: year, month: month, day: day)
            )
        } catch { dateInputError = "The calendar range is unavailable." }
    }

    private func updateAmount() {
        amountInputError = nil
        do {
            let lower = try parseAmount(minimumAmount)
            let upper = try parseAmount(maximumAmount)
            viewModel.presentationFilter.amountRange = lower == nil && upper == nil ? nil : .init(lowerBound: lower, upperBound: upper)
        } catch { amountInputError = "Enter a complete decimal amount without grouping or currency symbols." }
    }

    private func parseAmount(_ text: String) throws -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let body = trimmed.hasPrefix("-") || trimmed.hasPrefix("+") ? String(trimmed.dropFirst()) : trimmed
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard body.filter({ $0 != "." }).count <= 38,
              (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else {
            throw CocoaError(.formatting)
        }
        return value
    }

    private func clearFilters() {
        period = .all
        customStart = ""; customEnd = ""
        minimumAmount = ""; maximumAmount = ""
        dateInputError = nil; amountInputError = nil
        viewModel.clearPresentationCriteria()
    }

    private var matchingSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasUsableResults {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(totalKeys, id: \.self) { key in
                            if let money = result.totals.partitions[key] {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(totalTitle(key))
                                        .font(.system(size: 12)).foregroundStyle(secondary)
                                    Text(MoneyFormatting.display(money))
                                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(12)
                                .background(panelColor, in: RoundedRectangle(cornerRadius: 7))
                            }
                        }
                    }
                }
                if result.totals.withheldUnknownDomainCount + result.totals.withheldUnknownEffectCount > 0 {
                    Label("\(result.totals.withheldUnknownDomainCount + result.totals.withheldUnknownEffectCount) matching transactions have unestablished effects; their totals are withheld.",
                          systemImage: "info.circle")
                        .font(.system(size: 12)).foregroundStyle(secondary)
                }
            }
            if viewModel.presentationFilter.statementDateRange != nil && result.exclusions.period > 0 && inputError == nil {
                Text("\(result.exclusions.period) excluded by the period. Transactions without a source date are excluded.")
                    .font(.system(size: 12)).foregroundStyle(secondary)
            }
        }
    }

    private var totalKeys: [TransactionPresentationTotalKey] {
        result.totals.partitions.keys.sorted {
            if $0.currency.code != $1.currency.code { return $0.currency.code < $1.currency.code }
            if $0.domain.rawValue != $1.domain.rawValue { return $0.domain.rawValue < $1.domain.rawValue }
            return $0.effect.rawValue < $1.effect.rawValue
        }
    }

    private func totalTitle(_ key: TransactionPresentationTotalKey) -> String {
        let effect: String
        switch (key.domain, key.effect) {
        case (.bank, .credit): effect = "Bank · Inflow"
        case (.bank, .debit): effect = "Bank · Outflow"
        case (.card, .increasesAmountOwed): effect = "Card · Increase owed"
        case (.card, .decreasesAmountOwed): effect = "Card · Decrease owed"
        default: effect = "Total unavailable"
        }
        return "\(key.currency.code) · \(effect)"
    }

    /// Match the actual monospaced display font, including sign and currency.
    /// This measurement owns no AppKit view, window, or application lifecycle.
    private var amountColumnWidth: CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        return max(160, viewModel.allPresentationRows.reduce(CGFloat.zero) { width, row in
            max(width, (MoneyFormatting.display(row.transaction.money) as NSString).size(withAttributes: [.font: font]).width + 24)
        })
    }

    private var transactionTable: some View {
        VStack(spacing: 10) {
            Table(hasUsableResults ? result.rows : [], selection: selection, sortOrder: tableSort) {
                TableColumn("Date", sortUsing: TransactionTableComparator(key: .statementDate, order: .reverse)) { row in
                    HStack(spacing: 5) {
                        Image(systemName: row.id == viewModel.selectedPresentationRowID ? "checkmark" : "minus")
                            .font(.system(size: 10, weight: .bold))
                            .opacity(row.id == viewModel.selectedPresentationRowID ? 1 : 0)
                            .accessibilityHidden(true)
                        Text(row.sourceCivilDate?.presentation ?? "Unavailable")
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 8)
                }
                .width(min: 96, ideal: 112)
                TableColumn("Description", sortUsing: TransactionTableComparator(key: .description)) { row in
                    Text(row.transaction.description)
                        .lineLimit(2)
                        .help(row.transaction.description)
                        .padding(.vertical, 6)
                }
                .width(min: 220, ideal: 280)
                TableColumn("Account", sortUsing: TransactionTableComparator(key: .account)) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.accountDisplayName).lineLimit(1)
                        Text(row.institutionDisplayName)
                            .font(.system(size: 12)).foregroundStyle(secondary).lineLimit(1)
                    }
                    .help("\(row.accountDisplayName) · \(row.institutionDisplayName)")
                }
                .width(min: 136, ideal: 160)
                TableColumn("Category", sortUsing: TransactionTableComparator(key: .category)) { row in
                    Text(row.currentCategoryDisplayName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Color(hex: 0x292344), in: Capsule())
                        .help(row.currentCategoryDisplayName)
                }
                .width(min: 120, ideal: 144)
                TableColumn("Amount", sortUsing: TransactionTableComparator(key: .nativeAmount)) { row in
                    Text(MoneyFormatting.display(row.transaction.money))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: amountColumnWidth, ideal: amountColumnWidth)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
            .background(panelColor)
            .focused($tableFocused)
            .overlay {
                if !hasUsableResults {
                    outcomeState
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(panelColor)
                        .padding(.top, 28)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(tableFocused ? focusColor : Color(hex: 0x38445A), lineWidth: tableFocused ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            HStack(spacing: 12) {
                Text(inputError == nil && (result.state == .ready || result.state == .validEmpty)
                     ? "\(result.rows.count) matching · \(viewModel.allPresentationRows.count) total"
                     : "Results unavailable")
                    .font(.system(size: 12)).foregroundStyle(secondary)
                Spacer()
                Menu {
                    ForEach(TransactionPresentationSortKey.allCases, id: \.self) { key in
                        Button(sortTitle(key)) { viewModel.presentationSort.key = key }
                    }
                    Divider()
                    Button("Reverse direction") {
                        viewModel.presentationSort.direction = viewModel.presentationSort.direction == .ascending ? .descending : .ascending
                    }
                } label: {
                    Label("\(sortTitle(viewModel.presentationSort.key)) · \(viewModel.presentationSort.direction == .ascending ? "ascending" : "descending")",
                          systemImage: "arrow.up.arrow.down")
                }
                .fixedSize()
                .help("Sort all matching transactions. Currency groups remain separate.")
            }
        }
    }

    private func sortTitle(_ key: TransactionPresentationSortKey) -> String {
        switch key {
        case .statementDate: "Date"
        case .description: "Description"
        case .account: "Account"
        case .category: "Category"
        case .nativeAmount: "Amount"
        }
    }

    @ViewBuilder
    private var outcomeState: some View {
        if let message = inputError {
            LFEmptyState(title: "Check filters", message: message, systemImage: "exclamationmark.triangle")
        } else if availabilityState == .loading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading transactions…")
                Text("Waiting for current canonical data.").foregroundStyle(secondary)
            }
        } else {
            switch result.state {
            case .ready:
                EmptyView()
            case .validEmpty:
                VStack(spacing: 12) {
                    LFEmptyState(
                        title: viewModel.allPresentationRows.isEmpty ? "No transactions yet" : "No matching transactions",
                        message: viewModel.allPresentationRows.isEmpty
                            ? "Import a supported statement to see its transactions here."
                            : "Change the search or filters to see more transactions.",
                        systemImage: "tray"
                    )
                    if !viewModel.allPresentationRows.isEmpty {
                        Button("Clear filters", action: clearFilters).buttonStyle(.bordered)
                    }
                }
            case .unavailable:
                LFEmptyState(title: "Transactions unavailable", message: "Current canonical data could not be established. Check the application status before continuing.", systemImage: "exclamationmark.triangle")
            case .invalidAmountCurrencySelection:
                LFEmptyState(title: "Choose one currency", message: "An amount range requires exactly one selected native currency.", systemImage: "exclamationmark.triangle")
            case .invalidStatementDateRange:
                LFEmptyState(title: "Check source dates", message: "The start date must be on or before the end date.", systemImage: "exclamationmark.triangle")
            default:
                LFEmptyState(title: "Check filters", message: "A selected value or range is no longer valid. Clear filters or choose current values.", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var inspector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Transaction details").font(.headline)
                Spacer()
                Button {
                    detailsVisible = false
                    narrowDetailsVisible = false
                } label: { Image(systemName: "xmark") }
                .buttonStyle(.bordered)
                .help("Close transaction details")
                .accessibilityLabel("Close transaction details")
            }
            transactionDetailPanel
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    private var transactionDetailPanel: some View {
        LFPanel {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let selected = selectedTransaction {
                        let presentation = viewModel.detailPresentation(for: selected)
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(LFTheme.text)
                                .frame(width: 46, height: 46)
                                .background(Color(hex: 0x292344))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(presentation.description)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(presentation.signedAmount)
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(LFTheme.text)
                                    .monospacedDigit()
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(presentation.accessibilityText)

                        detailSection("Transaction") {
                            LFInfoRow(title: "Direction", value: presentation.direction, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: presentation.statementDateRole, value: presentation.statementDate, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Description", value: presentation.description, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Native currency", value: presentation.nativeCurrency, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Balance After", value: presentation.runningBalance, titleWidth: 100, verticalPadding: 0)
                        }

                        detailSection("Account and category") {
                            LFInfoRow(title: "Account", value: presentation.accountDisplayName, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Institution", value: presentation.institution, titleWidth: 100, verticalPadding: 0)
                            categoryPicker(for: selected, titleWidth: 100)
                        }

                        detailSection("Import provenance") {
                            LFInfoRow(title: "Availability", value: presentation.provenanceAvailability.title, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Source document", value: presentation.sourceDocumentName, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Imported", value: presentation.importedAtText, titleWidth: 100, verticalPadding: 0)
                        }

                        detailSection("Validation") {
                            if let validation = presentation.validation {
                                LFStatusBadge(
                                    title: validation.title,
                                    color: validation.isPassed ? LFTheme.success : LFTheme.warning
                                )
                                Text(validation.detail)
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                            } else {
                                LFInfoRow(title: "Outcome", value: "Unavailable", titleWidth: 100, verticalPadding: 0)
                                Text("Validation is unavailable for this imported transaction.")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                            }
                        }

                        if let categoryMessage {
                            Text(categoryMessage)
                                .font(.caption)
                                .foregroundStyle(LFTheme.warning)
                        }

                        if categoryReconciliationRequired {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your category change was saved, but the app could not refresh. Further category changes are temporarily blocked until the repository is refreshed.")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.warning)
                                Button("Retry refresh", action: retryCanonicalHydration)
                                    .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "cursorarrow.click")
                                .font(.system(size: 34))
                                .foregroundStyle(LFTheme.primaryHover)
                            Text("Select a transaction")
                                .font(.headline)
                            Text("Details appear here without leaving the transaction table.")
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
            }
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LFTheme.surfaceRaised.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LFTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func categoryPicker(for transaction: Transaction, titleWidth: CGFloat = 86) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Category")
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: titleWidth, alignment: .leading)
            Picker(
                "Category",
                selection: Binding<String?>(
                    get: {
                        guard let transactionID = transaction.repositoryTransactionId else { return nil }
                        return categoryStore.snapshot.assignments[transactionID]
                    },
                    set: { assign($0, to: transaction) }
                )
            ) {
                Text("Uncategorized").tag(String?.none)
                ForEach(assignableCategories(for: transaction)) { category in
                    Text(category.isArchived ? "\(category.name) (Archived)" : category.name)
                        .tag(Optional(category.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(transaction.repositoryTransactionId == nil)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
    }

    private func categoryName(for transaction: Transaction) -> String {
        guard let transactionID = transaction.repositoryTransactionId else { return "Uncategorized" }
        return categoryStore.category(forTransactionID: transactionID)?.name ?? "Uncategorized"
    }

    private func assignableCategories(for transaction: Transaction) -> [Category] {
        guard let transactionID = transaction.repositoryTransactionId,
              let assigned = categoryStore.category(forTransactionID: transactionID),
              assigned.isArchived else {
            return categoryStore.activeCategories
        }
        return (categoryStore.activeCategories + [assigned]).sorted {
            if $0.normalizedName != $1.normalizedName { return $0.normalizedName < $1.normalizedName }
            return $0.id < $1.id
        }
    }

    private func assign(_ categoryID: String?, to transaction: Transaction) {
        guard let transactionID = transaction.repositoryTransactionId else {
            categoryMessage = "Only persisted imported transactions can be classified."
            return
        }
        requestCategoryMutation(
            TransactionCategoryMutationIntent(
                categoryID: categoryID,
                transactionID: transactionID
            )
        )
    }

    private func requestCategoryMutation(_ intent: TransactionCategoryMutationIntent) {
#if DEBUG
        switch acknowledgementGate.authorization(for: intent.protectedAction) {
        case .allowed:
            executeCategoryMutation(intent)
        case .acknowledgementRequired(let challenge):
            pendingCategoryMutation = intent
            acknowledgementChallenge = challenge
        case .developmentDatabaseUnavailable:
            categoryMessage = "The development database is unavailable."
        }
#else
        executeCategoryMutation(intent)
#endif
    }

    private func executeCategoryMutation(_ intent: TransactionCategoryMutationIntent) {
        do {
            _ = try categoryCoordinator.setCategory(
                categoryID: intent.categoryID,
                transactionID: intent.transactionID
            )
            categoryMessage = nil
            categoryReconciliationRequired = false
        } catch {
#if DEBUG
            if let coordinatorError = error as? CategoryManagementCoordinatorError {
                switch coordinatorError {
                case .acknowledgementRequired(let challenge):
                    pendingCategoryMutation = intent
                    acknowledgementChallenge = challenge
                    return
                case .staleDevelopmentProfile:
                    pendingCategoryMutation = nil
                    acknowledgementChallenge = nil
                    categoryMessage = "The active development database changed. Start the category change again."
                    return
                default:
                    break
                }
            }
#endif
            categoryMessage = CategoryManagementPresentation.message(for: error)
            if let error = error as? CategoryManagementCoordinatorError {
                categoryReconciliationRequired = switch error {
                case .savedButRefreshFailed, .reconciliationRequired: true
                default: false
                }
            }
        }
    }

#if DEBUG
    private func approveDevelopmentProfileAcknowledgement() {
        guard let challenge = acknowledgementChallenge,
              let intent = pendingCategoryMutation else { return }
        switch acknowledgementGate.acknowledge(challenge) {
        case .granted, .noAcknowledgementRequired:
            pendingCategoryMutation = nil
            acknowledgementChallenge = nil
            executeCategoryMutation(intent)
        case .staleGeneration, .developmentDatabaseUnavailable:
            pendingCategoryMutation = nil
            acknowledgementChallenge = nil
            categoryMessage = "The active development database changed. Start the category change again."
        }
    }

    private func cancelDevelopmentProfileAcknowledgement() {
        pendingCategoryMutation = nil
        acknowledgementChallenge = nil
    }
#endif

    private func retryCanonicalHydration() {
        do {
            switch try categoryCoordinator.retryCanonicalHydration() {
            case .notRequired, .succeeded:
                categoryReconciliationRequired = false
                categoryMessage = nil
            case .failed:
                categoryReconciliationRequired = true
                categoryMessage = "The repository refresh is still unavailable. Category changes remain temporarily blocked."
            }
        } catch {
            categoryReconciliationRequired = true
            categoryMessage = CategoryManagementPresentation.message(for: error)
        }
    }

}

#Preview {
    TransactionListView()
}
