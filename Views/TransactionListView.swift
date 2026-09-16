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

/// Paints existing AppKit rows without replacing SwiftUI's Table or its input,
/// selection, sorting and reuse ownership. The row index is used only for stripes.
private struct TransactionRowBackdrop: NSViewRepresentable {
    @Environment(\.lfTheme) private var theme
    let isSelected: Bool
    let isEmphasized: Bool

    func makeNSView(context: Context) -> RowAppearanceView {
        let view = RowAppearanceView()
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: RowAppearanceView, context: Context) {
        view.theme = theme
        view.isSelected = isSelected
        view.isEmphasized = isEmphasized
        view.applyAppearance()
    }

    static func dismantleNSView(_ view: RowAppearanceView, coordinator: ()) {
        view.removeBackdrop()
    }

    final class RowAppearanceView: NSView {
        var theme = LFTheme.dark
        var isSelected = false
        var isEmphasized = false
        private let backdrop = CALayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            backdrop.cornerRadius = theme.radius.control
            backdrop.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            backdrop.actions = ["backgroundColor": NSNull(), "bounds": NSNull(), "position": NSNull()]
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            if superview == nil { removeBackdrop() }
            else { applyAppearance() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { removeBackdrop() }
            else { applyAppearance() }
        }

        override func layout() {
            super.layout()
            applyAppearance()
        }

        func removeBackdrop() { backdrop.removeFromSuperlayer() }

        func applyAppearance() {
            var ancestor = superview
            var rowView: NSTableRowView?
            while let view = ancestor {
                if let row = view as? NSTableRowView { rowView = row }
                if let table = view as? NSTableView, let rowView {
                    // Public AppKit surfaces share the same viewport/scroll-gutter tint.
                    table.backgroundColor = NSColor(theme.palette.controlSurface)
                    if let scroll = table.enclosingScrollView {
                        scroll.drawsBackground = false
                        scroll.contentView.drawsBackground = false
                    }
                    let index = table.row(for: rowView)
                    guard index >= 0 else { return }
                    // Suppress only AppKit's system-colored selection drawing.
                    // Native selection state and the existing checkmark remain.
                    if table.selectionHighlightStyle != .none {
                        table.selectionHighlightStyle = .none
                    }
                    if rowView.selectionHighlightStyle != .none {
                        rowView.selectionHighlightStyle = .none
                    }
                    let color = theme.interaction.dataRow(
                        selected: isSelected,
                        active: isEmphasized,
                        alternate: !index.isMultiple(of: 2)
                    )
                    backdrop.cornerRadius = theme.radius.control
                    // AppKit refreshes backgroundColor during selection changes.
                    // Keep this noninteractive wash above that background and
                    // below native cell content so stripes survive the refresh.
                    rowView.wantsLayer = true
                    guard let rowLayer = rowView.layer else { return }
                    if backdrop.superlayer !== rowLayer {
                        backdrop.removeFromSuperlayer()
                        rowLayer.insertSublayer(backdrop, at: 0)
                    }
                    backdrop.frame = rowView.bounds
                    backdrop.backgroundColor = NSColor(color).cgColor
                    return
                }
                ancestor = view.superview
            }
        }
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

/// One scalar measurement for the current row revision and actual native font.
/// Query/selection changes do not cause another full amount-measurement pass.
@MainActor
final class TransactionAmountWidthMeasurement {
    private var revision: UInt64?
    private var font: NSFont?
    private var width: CGFloat = 160

    func value(revision: UInt64, font: NSFont, measure: () -> CGFloat) -> CGFloat {
        if self.revision == revision, self.font == font { return width }
        width = measure()
        self.revision = revision
        self.font = font
        return width
    }
}

/// Session-only input state stays aligned with the retained query; no preference
/// or financial source is persisted by these controls.
struct TransactionPresentationControls {
    var period: TransactionPeriodChoice = .all
    var customStart = ""
    var customEnd = ""
    var minimumAmount = ""
    var maximumAmount = ""
    var amountInputError: String?
    var dateInputError: String?
}

struct TransactionListView: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    @StateObject private var viewModel: TransactionListViewModel
    @State private var amountMeasurement: TransactionAmountWidthMeasurement
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
    private var period: TransactionPeriodChoice {
        get { viewModel.presentationControls.period }
        nonmutating set {
            if viewModel.presentationControls.period != newValue { viewModel.presentationControls.period = newValue }
        }
    }
    private var customStart: String {
        get { viewModel.presentationControls.customStart }
        nonmutating set {
            if viewModel.presentationControls.customStart != newValue { viewModel.presentationControls.customStart = newValue }
        }
    }
    private var customEnd: String {
        get { viewModel.presentationControls.customEnd }
        nonmutating set {
            if viewModel.presentationControls.customEnd != newValue { viewModel.presentationControls.customEnd = newValue }
        }
    }
    private var minimumAmount: String {
        get { viewModel.presentationControls.minimumAmount }
        nonmutating set {
            if viewModel.presentationControls.minimumAmount != newValue { viewModel.presentationControls.minimumAmount = newValue }
        }
    }
    private var maximumAmount: String {
        get { viewModel.presentationControls.maximumAmount }
        nonmutating set {
            if viewModel.presentationControls.maximumAmount != newValue { viewModel.presentationControls.maximumAmount = newValue }
        }
    }
    private var amountInputError: String? {
        get { viewModel.presentationControls.amountInputError }
        nonmutating set {
            if viewModel.presentationControls.amountInputError != newValue { viewModel.presentationControls.amountInputError = newValue }
        }
    }
    private var dateInputError: String? {
        get { viewModel.presentationControls.dateInputError }
        nonmutating set {
            if viewModel.presentationControls.dateInputError != newValue { viewModel.presentationControls.dateInputError = newValue }
        }
    }
    @State private var categoryMessage: String?
    @State private var categoryReconciliationRequired = false
    @FocusState private var searchFocused: Bool
    @FocusState private var tableFocused: Bool
#if DEBUG
    @State private var pendingCategoryMutation: TransactionCategoryMutationIntent?
    @State private var acknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
#endif

    private var secondary: Color { theme.palette.secondaryText }
    private var panelColor: Color { theme.palette.contentSurface }
    private var controlBorder: Color { theme.palette.fieldBorder }
    private var focusColor: Color { theme.interaction.focusRing }

#if DEBUG
    @MainActor
    init(
        viewModel: TransactionListViewModel? = nil,
        amountMeasurement: TransactionAmountWidthMeasurement? = nil,
        generation: ProviderGenerationToken? = nil,
        availabilityState: ApplicationDataState = .loading,
        categoryStore: CategoryStore? = nil,
        categoryCoordinator: CategoryManaging? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self._viewModel = StateObject(wrappedValue: viewModel ?? TransactionListViewModel())
        self._amountMeasurement = State(initialValue: amountMeasurement ?? TransactionAmountWidthMeasurement())
        self.categoryStore = resolvedStore
        self.categoryCoordinator = categoryCoordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
        self.acknowledgementGate = acknowledgementGate ?? .shared
        self.generation = generation
        self.availabilityState = availabilityState
    }
#else
    @MainActor
    init(
        viewModel: TransactionListViewModel? = nil,
        amountMeasurement: TransactionAmountWidthMeasurement? = nil,
        generation: ProviderGenerationToken? = nil,
        availabilityState: ApplicationDataState = .loading,
        categoryStore: CategoryStore? = nil,
        categoryCoordinator: CategoryManaging? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self._viewModel = StateObject(wrappedValue: viewModel ?? TransactionListViewModel())
        self._amountMeasurement = State(initialValue: amountMeasurement ?? TransactionAmountWidthMeasurement())
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
            .padding(theme.spacing.pagePadding)
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
        .foregroundStyle(theme.palette.primaryText)
        .font(theme.typography.tableBody)
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
        updatePeriod()
        updateAmount()
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
            .background(panelColor, in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay(RoundedRectangle(cornerRadius: theme.radius.control).stroke(searchFocused ? focusColor : controlBorder, lineWidth: searchFocused ? 2 : 1))

            Picker("Period", selection: $viewModel.presentationControls.period) {
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
            .lfSecondaryAction()
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
                if activeCriteriaCount > 0 {
                    Text("\(activeCriteriaCount) active criteria · all matching transactions")
                        .font(theme.typography.caption)
                        .foregroundStyle(secondary)
                }
                Spacer(minLength: 0)
                Button("Clear filters", action: clearFilters)
                    .lfSecondaryAction()
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
            Section("Card liabilities") {
                Toggle("Increase owed", isOn: membership(\.effects, .increasesAmountOwed))
                Toggle("Decrease owed", isOn: membership(\.effects, .decreasesAmountOwed))
            }
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
            .lfSecondaryAction()
            .accessibilityLabel("More filters")
            .popover(isPresented: $moreFiltersVisible, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("More filters").font(theme.typography.formHeading)
                    HStack { familyMenu; effectMenu }
                    institutionMenu
                    Divider()
                    Text("Amount range").font(theme.typography.formHeading)
                    Text("Choose one native currency. Bounds include the entered amounts.")
                        .font(theme.typography.caption).foregroundStyle(secondary)
                    currencyMenu
                    HStack {
                        TextField("Minimum", text: $viewModel.presentationControls.minimumAmount)
                            .lfTextField()
                            .accessibilityLabel("Minimum native amount")
                        TextField("Maximum", text: $viewModel.presentationControls.maximumAmount)
                            .lfTextField()
                            .accessibilityLabel("Maximum native amount")
                    }
                    Text("Use a decimal point; leave a bound empty for no limit.")
                        .font(theme.typography.caption).foregroundStyle(secondary)
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
            .font(theme.typography.secondary)
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
            TextField("From YYYY-MM-DD", text: $viewModel.presentationControls.customStart)
                .lfTextField()
                .accessibilityLabel("Source date from, year month day")
            Text("to").foregroundStyle(secondary)
            TextField("Through YYYY-MM-DD", text: $viewModel.presentationControls.customEnd)
                .lfTextField()
                .accessibilityLabel("Source date through, year month day")
            Text("Inclusive").font(theme.typography.caption).foregroundStyle(secondary)
        }
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
                                        .font(theme.typography.caption).foregroundStyle(secondary)
                                    Text(MoneyFormatting.display(money))
                                        .font(theme.typography.tableSummary)
                                        .foregroundStyle(theme.financialEffectColor(key.effect))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(12)
                                .background(theme.palette.raisedSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
                            }
                        }
                    }
                }
                if result.totals.withheldUnknownDomainCount + result.totals.withheldUnknownEffectCount > 0 {
                    Label("\(result.totals.withheldUnknownDomainCount + result.totals.withheldUnknownEffectCount) matching transactions have unestablished effects; their totals are withheld.",
                          systemImage: "info.circle")
                        .font(theme.typography.caption).foregroundStyle(secondary)
                }
            }
            if viewModel.presentationFilter.statementDateRange != nil && result.exclusions.period > 0 && inputError == nil {
                Text("\(result.exclusions.period) excluded by the period. Transactions without a source date are excluded.")
                    .font(theme.typography.caption).foregroundStyle(secondary)
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

    /// Match the system display font with tabular digits, including sign and currency.
    /// This measurement owns no AppKit view, window, or application lifecycle.
    private var amountColumnWidth: CGFloat {
        let font = theme.typography.nativeFont(.tableMoney)
        return amountMeasurement.value(revision: viewModel.canonicalContentRevision, font: font) {
            max(160, viewModel.allPresentationRows.reduce(CGFloat.zero) { width, row in
                max(width, (MoneyFormatting.display(row.transaction.money) as NSString).size(withAttributes: [.font: font]).width + 24)
            })
        }
    }

    private var transactionTable: some View {
        VStack(spacing: 10) {
            Table(hasUsableResults ? result.rows : [], selection: selection, sortOrder: tableSort) {
                TableColumn(sortHeader(.statementDate), sortUsing: TransactionTableComparator(key: .statementDate, order: .reverse)) { row in
                    HStack(spacing: 5) {
                        Image(systemName: row.id == viewModel.selectedPresentationRowID ? "checkmark" : "minus")
                            .font(theme.typography.tableSelectionMark)
                            .opacity(row.id == viewModel.selectedPresentationRowID ? 1 : 0)
                            .accessibilityHidden(true)
                        Text(row.sourceCivilDate?.presentation ?? "Unavailable")
                            .font(theme.typography.secondary)
                    }
                    .padding(.vertical, theme.spacing.small)
                    .frame(minHeight: theme.typography.tableRowMinimum)
                    .background {
                        TransactionRowBackdrop(
                            isSelected: row.id == viewModel.selectedPresentationRowID,
                            isEmphasized: tableFocused && appearsActive
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
                .width(min: 96, ideal: 112)
                TableColumn(sortHeader(.description), sortUsing: TransactionTableComparator(key: .description)) { row in
                    Text(row.transaction.description)
                        .lineLimit(2)
                        .help(row.transaction.description)
                        .padding(.vertical, 6)
                }
                .width(min: 220, ideal: 280)
                TableColumn(sortHeader(.account), sortUsing: TransactionTableComparator(key: .account)) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.accountDisplayName).lineLimit(1)
                        Text(row.institutionDisplayName)
                            .font(theme.typography.caption).foregroundStyle(secondary).lineLimit(1)
                    }
                    .help("\(row.accountDisplayName) · \(row.institutionDisplayName)")
                }
                .width(min: 136, ideal: 160)
                TableColumn(sortHeader(.category), sortUsing: TransactionTableComparator(key: .category)) { row in
                    Text(row.currentCategoryDisplayName)
                        .font(theme.typography.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(theme.interaction.dataBadge, in: Capsule())
                        .help(row.currentCategoryDisplayName)
                }
                .width(min: 120, ideal: 144)
                TableColumn(sortHeader(.nativeAmount), sortUsing: TransactionTableComparator(key: .nativeAmount)) { row in
                    Text(MoneyFormatting.display(row.transaction.money))
                        .font(theme.typography.tableMoney)
                        .foregroundStyle(theme.financialEffectColor(row.effect))
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: amountColumnWidth, ideal: amountColumnWidth)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .tint(theme.palette.dataSelection)
            .scrollContentBackground(.hidden)
            .background(panelColor)
            .focused($tableFocused)
            .focusEffectDisabled()
            .overlay {
                if !hasUsableResults {
                    outcomeState
                        .padding(theme.spacing.pagePadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(panelColor)
                        .padding(.top, 28)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: theme.radius.panel).strokeBorder(theme.palette.tableBorder, lineWidth: 1).allowsHitTesting(false))
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel))

            HStack(spacing: 12) {
                Text(inputError == nil && (result.state == .ready || result.state == .validEmpty)
                     ? "\(result.rows.count) matching · \(viewModel.allPresentationRows.count) total"
                     : "Results unavailable")
                    .font(theme.typography.caption).foregroundStyle(secondary)
                Spacer()
            }
        }
    }

    private func sortHeader(_ key: TransactionPresentationSortKey) -> Text {
        let title = sortTitle(key)
        // The active column keeps AppKit's native direction indicator. Other
        // headers show a quiet sorting hint without adding another control.
        if viewModel.presentationSort.key == key { return Text(title) }
        let hint = Text(Image(systemName: "arrow.up.arrow.down"))
            .font(theme.typography.tableSortIcon)
            .foregroundColor(theme.palette.secondaryText.opacity(0.6))
        return Text("\(title)  \(hint)")
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
                        Button("Clear filters", action: clearFilters).lfSecondaryAction()
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
                Text("Transaction details").font(theme.typography.formHeading)
                Spacer()
                Button {
                    detailsVisible = false
                    narrowDetailsVisible = false
                } label: { Image(systemName: "xmark") }
                .lfSecondaryAction()
                .help("Close transaction details")
                .accessibilityLabel("Close transaction details")
            }
            transactionDetailPanel
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    private var transactionDetailPanel: some View {
        LFPanel(variant: .inspector) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let selected = selectedTransaction {
                        let presentation = viewModel.detailPresentation(for: selected)
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(theme.palette.primaryText)
                                .frame(width: 46, height: 46)
                                .background(theme.interaction.dataIcon)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(presentation.description)
                                    .font(theme.typography.formHeading)
                                    .lineLimit(2)
                                Text(presentation.signedAmount)
                                    .font(theme.typography.body.weight(.semibold))
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(theme.palette.primaryText)
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
                                    .font(theme.typography.formCaption)
                                    .foregroundStyle(theme.palette.secondaryText)
                            } else {
                                LFInfoRow(title: "Outcome", value: "Unavailable", titleWidth: 100, verticalPadding: 0)
                                Text("Validation is unavailable for this imported transaction.")
                                    .font(theme.typography.formCaption)
                                    .foregroundStyle(theme.palette.secondaryText)
                            }
                        }

                        if let categoryMessage {
                            Text(categoryMessage)
                                .font(theme.typography.formCaption)
                                .foregroundStyle(LFTheme.warning)
                        }

                        if categoryReconciliationRequired {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your category change was saved, but the app could not refresh. Further category changes are temporarily blocked until the repository is refreshed.")
                                    .font(theme.typography.formCaption)
                                    .foregroundStyle(LFTheme.warning)
                                Button("Retry refresh", action: retryCanonicalHydration)
                                    .lfSecondaryAction()
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "cursorarrow.click")
                                .font(theme.typography.emptyStateIcon)
                                .foregroundStyle(theme.palette.accentHover)
                            Text("Select a transaction")
                                .font(theme.typography.formHeading)
                            Text("Details appear here without leaving the transaction table.")
                                .font(theme.typography.formCaption)
                                .foregroundStyle(theme.palette.secondaryText)
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
                .font(theme.typography.formHeading)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lfSurface(.subtle)
    }

    private func categoryPicker(for transaction: Transaction, titleWidth: CGFloat = 86) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Category")
                .foregroundStyle(theme.palette.secondaryText)
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
        .font(theme.typography.formCaption)
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
