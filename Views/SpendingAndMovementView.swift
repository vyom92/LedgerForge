import SwiftUI
import Charts
import Combine


/// Native, currency-specific charts and reversible owner review over the
/// already-hydrated graph. Chart marks are approximate geometry only; the
/// adjacent values and drill-down always use exact native Decimal amounts.
struct SpendingAndMovementView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject private var store = FinancialIntelligenceStore.shared
    private let reconciliation = CategoryReconciliationGate.shared
    @ObservedObject var model: SpendingAnalysisModel
    let generation: ProviderGenerationToken?
    let availability: ApplicationDataState
    let isActive: Bool
    let onBack: () -> Void
    let onTransactions: (Set<String>) -> Void
    let onCategories: () -> Void
    var onPeriodOverview: ((TransactionPresentationFilterSpec) -> Void)? = nil
    @State private var currency = "INR"
    @State private var accountID = ""
    @State private var startText = ""
    @State private var endText = ""
    @State private var baselineStartText = ""
    @State private var baselineEndText = ""
    @State private var appliedStart = ""
    @State private var appliedEnd = ""
    @State private var appliedBaselineStart = ""
    @State private var appliedBaselineEnd = ""
    @State private var monthText = String(FinancialCalendar.statement(Date())!.canonical.prefix(7))
    @State private var periodMode = "Calendar months"
    @State private var initializedPeriod = false
    @State private var section = "Spending"
    @State private var reviewKind = "Suggestions"
    @State private var selection: MovementReviewDraft?
    @State private var message: String?
    @State private var showsPeriods = false
    @State private var showsComparisonDetails = false
    @State private var reviewLimit = 40
    @State private var contentWidth: CGFloat = 1000
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pending: (() -> Void)?
#endif
    private var usable: Bool { (availability == .current || availability == .empty) && generation == store.generation && store.snapshot != nil }
    private var inputError: String? {
        if !startText.isEmpty && (try? StatementDate(canonical: startText)) == nil { return "Enter the start date as YYYY-MM-DD." }
        if !endText.isEmpty && (try? StatementDate(canonical: endText)) == nil { return "Enter the end date as YYYY-MM-DD." }
        if !startText.isEmpty && !endText.isEmpty && startText > endText { return "The start date must be on or before the end date." }
        if periodMode != "All dates" {
            if (try? StatementDate(canonical: startText)) == nil || (try? StatementDate(canonical: endText)) == nil { return "Choose a complete analysis range as YYYY-MM-DD." }
            if (try? StatementDate(canonical: baselineStartText)) == nil || (try? StatementDate(canonical: baselineEndText)) == nil { return "Choose a complete comparison range as YYYY-MM-DD." }
            if baselineStartText > baselineEndText { return "The comparison start must be on or before its end." }
        }
        return nil
    }

    var body: some View {
        let pagePadding = theme.spacing.pagePadding
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                header
                if !usable {
                    ContentUnavailableView("Financial context unavailable", systemImage: "chart.bar.xaxis", description: Text("Resolve the ledger status in Settings, then return to Transactions."))
                } else {
                    controls
                    Text(activeScope).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    if unappliedDates { Text("Date edits have not been applied. Results still use the period shown above.").foregroundStyle(LFTheme.warning) }
                    if let inputError { Text(inputError).foregroundStyle(LFTheme.warning) }
                    if let message { Text(message).foregroundStyle(LFTheme.warning).textSelection(.enabled) }
                    if let generation, reconciliation.isBlocked(for: generation) {
                        Button("Reload saved decisions") { perform { try FinancialIntelligenceCoordinator().retryRefresh(workspaceID: store.snapshot!.workspaceID, generation: generation) } }
                    }
                    if model.isWorking { ProgressView("Reading recorded activity…").frame(maxWidth: .infinity, minHeight: 200) }
                    else if let projection = model.projection {
                        if section == "Spending" { spending(projection) }
                        else { movements(projection) }
                    }
                }
            }
            .padding(theme.spacing.pagePadding)
        }
        .foregroundStyle(theme.palette.primaryText)
        .font(theme.typography.body)
        .onGeometryChange(for: CGFloat.self) { $0.size.width - pagePadding * 2 } action: { contentWidth = $0 }
        .onAppear { if !initializedPeriod { initializedPeriod = true; selectCalendarMonth(); applyDates() } else { refresh() } }
        .onDisappear { model.cancel() }
        .onChange(of: isActive) { _, _ in refresh() }
        .onChange(of: store.revision) { _, _ in refresh() }
        .onChange(of: availability) { _, _ in selection = nil; refresh() }
        .onChange(of: generation) { _, _ in selection = nil; refresh() }
        .onChange(of: currency) { _, _ in accountID = ""; refresh() }
        .onChange(of: accountID) { _, _ in refresh() }
        .sheet(item: $selection) { draft in
            MovementReviewEditor(draft: draft, rows: model.sourceRows, generation: generation, sources: store.sources,
                historyScope: relationshipHistoryScope)
        }
#if DEBUG
        .alert(DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pending = nil } })) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                if let challenge { _ = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) }
                let action = pending; pending = nil; challenge = nil; action?()
            }
            Button("Cancel", role: .cancel) { challenge = nil; pending = nil }
        } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Transactions").font(theme.typography.pageTitle)
                Text("Spending & movements").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            HStack(spacing: 16) {
                Button(action: onBack) { Label("Transactions", systemImage: "chevron.left") }.lfSecondaryAction()
                Picker("View", selection: $section) {
                    Text("Spending").tag("Spending")
                    Text("Movement review").tag("Movement review")
                }.labelsHidden().pickerStyle(.segmented).frame(width: 360)
                Spacer(minLength: 12)
                if let onPeriodOverview {
                    Button("Period overview") { onPeriodOverview(overviewFilter) }
                        .lfSecondaryAction().accessibilityIdentifier("spending.periodOverview")
                }
            }
        }
    }
    private var overviewFilter: TransactionPresentationFilterSpec {
        var filter = TransactionPresentationFilterSpec()
        filter.currencies = [CurrencyCode(rawValue: currency)]
        if !accountID.isEmpty { filter.accountIDs = [accountID] }
        let start = try? StatementDate(canonical: appliedStart)
        let end = try? StatementDate(canonical: appliedEnd)
        if start != nil || end != nil {
            filter.statementDateRange = .init(start: start, end: end)
        }
        return filter
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if contentWidth >= 1260 && periodMode != "Custom ranges" {
                HStack(alignment: .lastTextBaseline, spacing: 16) { scopeControls; dateControls }
            } else {
                scopeControls
                dateControls
            }
        }.onChange(of: periodMode) { _, mode in
            if mode == "Calendar months" { selectCalendarMonth() }
            else if mode == "All dates" { startText = ""; endText = ""; baselineStartText = ""; baselineEndText = "" }
            applyDates()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var scopeControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { currencyControl; accountControl; periodControl }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) { currencyControl; periodControl }
                accountControl
            }
        }
    }
    private var periodControl: some View {
        Picker("Periods", selection: $periodMode) {
            ForEach(["Calendar months", "Custom ranges", "All dates"], id: \.self) { Text($0) }
        }.tint(theme.palette.primaryText).frame(width: 245)
    }
    private var currencyControl: some View {
        Picker("Currency", selection: $currency) {
            if !store.sources.accounts.contains(where: { $0.currency == currency }) {
                Text("\(currency) · no accounts").tag(currency)
            }
            ForEach(Set(store.sources.accounts.map(\.currency)).sorted(), id: \.self) { Text($0).tag($0) }
        }.tint(theme.palette.primaryText).frame(width: 165)
    }
    private var accountControl: some View {
        LFAccountMenu(title: store.sources.accounts.first { $0.id == accountID }?.title ?? "Current \(currency) accounts",
            allTitle: "Current \(currency) accounts", options: store.sources.accounts.filter { $0.currency == currency }.map {
                .init(id: $0.id, title: $0.title, detail: $0.selectionContext, selected: accountID == $0.id)
            }) { accountID = $0 ?? "" }
            .accessibilityLabel("Account").frame(minWidth: 220, idealWidth: 290, maxWidth: 340)
    }
    @ViewBuilder private var dateControls: some View {
        if periodMode == "Calendar months" {
            HStack(spacing: 10) {
                Text("Analysis month").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                TextField("YYYY-MM", text: $monthText).frame(width: 110).onSubmit { selectCalendarMonth(); applyDates() }
                    .accessibilityLabel("Analysis month")
                Button("Apply month") { selectCalendarMonth(); applyDates() }.lfSecondaryAction()
                    .disabled((try? SelectedStatementMonth(canonical: monthText)) == nil)
            }.textFieldStyle(.roundedBorder)
                .help("Compared with the previous calendar month. Current month stops today.")
        } else if periodMode == "Custom ranges" {
            VStack(alignment: .leading, spacing: 8) {
                rangeFields("Analysis", start: $startText, end: $endText)
                rangeFields("Comparison", start: $baselineStartText, end: $baselineEndText)
                Button("Apply ranges", action: applyDates).lfSecondaryAction().disabled(inputError != nil)
            }
        }
    }
    private func rangeFields(_ title: String, start: Binding<String>, end: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 105, alignment: .leading)
            TextField("From YYYY-MM-DD", text: start).frame(width: 155)
            Text("to").foregroundStyle(theme.palette.secondaryText)
            TextField("To YYYY-MM-DD", text: end).frame(width: 155)
        }.textFieldStyle(.roundedBorder)
    }
    private func selectCalendarMonth() {
        guard let month = try? SelectedStatementMonth(canonical: monthText),
              let first = try? StatementDate(canonical: month.canonical + "-01"),
              let last = FinancialCalendar.lastDay(month),
              let previousLast = FinancialCalendar.addDays(-1, to: first),
              let today = FinancialCalendar.statement(Date()) else { return }
        startText = first.canonical
        endText = (today >= first && today <= last ? today : last).canonical
        baselineStartText = String(previousLast.canonical.prefix(7)) + "-01"
        baselineEndText = previousLast.canonical
    }

    private var activeScope: String {
        let account = store.sources.accounts.first { $0.id == accountID }?.title ?? "Current \(currency) accounts"
        let from = (try? StatementDate(canonical: appliedStart))?.presentation
        let to = (try? StatementDate(canonical: appliedEnd))?.presentation
        let period = from == nil && to == nil ? "all recorded dates" : "\(from ?? "earliest record") – \(to ?? "latest record")"
        return "Showing \(account) · \(period). Review counts apply only to this selection."
    }
    private var unappliedDates: Bool {
        startText != appliedStart || endText != appliedEnd || baselineStartText != appliedBaselineStart || baselineEndText != appliedBaselineEnd ||
            (periodMode == "Calendar months" && monthText != String(appliedStart.prefix(7)))
    }
    private func applyDates() {
        guard inputError == nil else { return }
        appliedStart = startText; appliedEnd = endText
        appliedBaselineStart = baselineStartText; appliedBaselineEnd = baselineEndText
        refresh()
    }

    @ViewBuilder private func spending(_ value: SpendingProjection) -> some View {
        if let comparison = model.comparison {
            comparisonView(comparison)
        } else {
            recordedHistory(value)
        }
    }

    @ViewBuilder private func recordedHistory(_ value: SpendingProjection) -> some View {
        let plottedPeriods = value.periods.filter { $0.income != 0 || $0.spending != 0 }
        let labelCount = min(6, plottedPeriods.count)
        let labelIndices = Set((0..<labelCount).map { labelCount < 2 ? 0 : $0 * (plottedPeriods.count - 1) / (labelCount - 1) })
        let labelledPeriods = plottedPeriods.enumerated().compactMap { index, period in
            labelIndices.contains(index) ? period : nil
        }
        LFPanel {
            let layout = contentWidth >= 1000 ? AnyLayout(HStackLayout(alignment: .top, spacing: 30)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            layout {
                total("Recorded spending", value.spending).frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 12) {
                    total("Recorded income", value.income)
                    Text("Interpretation and coverage may be incomplete.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Needs review").font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    Text(value.unresolvedCount.formatted()).font(theme.typography.headlineMoney).monospacedDigit().foregroundStyle(LFTheme.warning)
                    Button("Review financial treatment") { section = "Movement review"; reviewKind = "Needs review" }.lfSecondaryAction()
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if value.missingDateCount > 0 { Text("\(value.missingDateCount) undated transactions are outside the time chart.").font(theme.typography.formCaption) }
        if value.rows.isEmpty { ContentUnavailableView("No recorded activity in this selection", systemImage: "chart.bar.xaxis") }
        else {
            LFPanel(title: "Income and spending") {
                if !plottedPeriods.isEmpty {
                Chart(plottedPeriods) { period in
                    BarMark(x: .value("Month", period.id), y: .value("Native amount", geometry(period.income)))
                        .foregroundStyle(by: .value("Role", "Income")).position(by: .value("Role", "Income"))
                        .accessibilityLabel("\(period.title), recorded income \(amount(period.income))")
                    BarMark(x: .value("Month", period.id), y: .value("Native amount", geometry(period.spending)))
                        .foregroundStyle(by: .value("Role", "Spending")).position(by: .value("Role", "Spending"))
                        .accessibilityLabel("\(period.title), recorded spending \(amount(period.spending))")
                }
                .chartForegroundStyleScale(["Income": Color.mint, "Spending": Color.cyan])
                .chartXAxis {
                    AxisMarks(values: labelledPeriods.map(\.id)) { axis in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(collisionResolution: .disabled) {
                            if let id = axis.as(String.self), let period = labelledPeriods.first(where: { $0.id == id }) {
                                Text(axisMonth(period.id)).font(theme.typography.secondary)
                                    .multilineTextAlignment(.center).fixedSize()
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { axis in
                        AxisGridLine()
                        AxisValueLabel {
                            if let value = axis.as(Double.self) { Text(axisAmount(value)).font(theme.typography.secondary) }
                        }
                    }
                }
                .frame(height: 230).accessibilityIdentifier("spending.periodChart")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Monthly income and spending in \(currency)")
                .accessibilityValue(plottedPeriods.map {
                    "\($0.title): recorded income \(amount($0.income)), recorded spending \(amount($0.spending))"
                }.joined(separator: "; "))
                .accessibilityHint("Open Monthly values and coverage for exact amounts and source transactions.")
                Text("Missing bars do not mean zero spending.")
                    .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                } else {
                    Text("No nonzero recorded amounts are available to plot in this selection.")
                        .foregroundStyle(theme.palette.secondaryText)
                }
            }
            LFPanel {
                DisclosureGroup("Monthly values & coverage", isExpanded: $showsPeriods) {
                    Text("Source transaction dates are used where available; otherwise the labelled financial date. Unresolved movements and missing coverage prevent a complete surplus estimate.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText).padding(.vertical, 8)
                    ForEach(value.periods) { period in
                        Button { onTransactions(period.transactionIDs) } label: {
                            HStack {
                                Text(period.title).frame(width: 80, alignment: .leading)
                                Text(period.transactionIDs.isEmpty ? "No observed activity" : "\(amount(period.income)) income · \(amount(period.spending)) spending")
                                Spacer()
                                Text(period.incompleteAccounts.isEmpty && period.unresolvedIDs.isEmpty ? "Covered" : "\(period.unresolvedIDs.count) unresolved · \(period.incompleteAccounts.count) accounts with gaps")
                            }.font(theme.typography.formCaption).padding(.vertical, 4)
                        }.buttonStyle(.plain).disabled(period.transactionIDs.isEmpty)
                        .help(period.incompleteAccounts.isEmpty ? "Open the exact source transactions" : "Coverage missing: " + period.incompleteAccounts.joined(separator: ", "))
                    }
                }
            }
            LFPanel(title: "Spending by category") {
                if value.categories.isEmpty { Text("No spending is yet recognized in this selection.").foregroundStyle(theme.palette.secondaryText) }
                else if value.categories.count == 1 && value.categories.first?.id == "uncategorized" {
                    Text("Recorded spending has no categories yet. Review transactions or apply category rules to see category drivers.")
                    HStack {
                        Button("Review transactions") { onTransactions(value.categories[0].transactionIDs) }.lfSecondaryAction()
                        Button("Category rules", action: onCategories).lfSecondaryAction()
                    }
                }
                else {
                    Chart(value.categories) { item in
                        BarMark(x: .value("Native amount", geometry(item.amount)), y: .value("Category", item.title))
                            .foregroundStyle(item.id == "uncategorized" || item.id == "conflict" ? theme.palette.secondaryText : Color.cyan)
                            .accessibilityLabel("\(item.title), \(amount(item.amount))")
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { axis in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let value = axis.as(Double.self) { Text(axisAmount(value)).font(theme.typography.secondary) }
                            }
                        }
                    }
                    .frame(height: CGFloat(max(120, value.categories.count * 32)))
                        .accessibilityIdentifier("spending.categoryChart")
                    ForEach(value.categories) { item in
                        Button { onTransactions(item.transactionIDs) } label: {
                            HStack { Text(item.title); Spacer(); Text(amount(item.amount)).monospacedDigit(); Image(systemName: "chevron.right") }
                                .padding(.vertical, 5)
                        }.buttonStyle(.plain).help("Open the \(item.transactionIDs.count) transactions behind this category total")
                    }
                }
            }
        }
    }
    private func total(_ title: String, _ number: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).foregroundStyle(theme.palette.secondaryText).font(theme.typography.secondary)
            Text(amount(number)).font(theme.typography.headlineMoney).monospacedDigit().fixedSize(horizontal: true, vertical: false)
        }
    }
    private func comparisonView(_ value: SpendingComparison) -> some View {
        let hasBothPeriods = !value.analysis.report.rows.isEmpty && !value.baseline.report.rows.isEmpty
        return VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            if hasBothPeriods {
                let layout = contentWidth >= 1120 ? AnyLayout(HStackLayout(alignment: .top, spacing: 18)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                layout {
                    comparisonPrimary(value).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 16) {
                        comparisonReview(value)
                        LFPanel(title: "Category drivers") { categoryDrivers(value) }
                    }.frame(width: contentWidth >= 1120 ? contentWidth * 0.35 : nil)
                }
            } else {
                LFPanel { missingComparison(value) }
            }
            LFPanel {
                DisclosureGroup("Coverage and calculation", isExpanded: $showsComparisonDetails) {
                    VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                        if !hasBothPeriods {
                            Text("These are differences between recorded totals only. Missing records do not establish a spending reduction.")
                                .foregroundStyle(LFTheme.warning)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), alignment: .topLeading), count: contentWidth >= 820 ? 2 : 1), alignment: .leading, spacing: 24) {
                            comparisonPeriod(value.analysis, title: "Analysis")
                            comparisonPeriod(value.baseline, title: "Comparison")
                        }
                        let layout = contentWidth >= 900 ? AnyLayout(HStackLayout(alignment: .top, spacing: 30)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                        layout {
                            difference("Recorded income difference", value.incomeChange, baseline: value.baseline.report.income,
                                ids: recognizedIDs(value.analysis.report, treatment: .income).union(recognizedIDs(value.baseline.report, treatment: .income)))
                            difference("Recorded spending difference", value.spendingChange, baseline: value.baseline.report.spending,
                                ids: spendingIDs(value.analysis.report).union(spendingIDs(value.baseline.report)))
                        }
                        Text("Same \(currency) accounts and recognition rules in both periods. Source transaction dates are used where available; otherwise the labelled financial date. Purchases count once on their original dates. Refunds and charges are separate; loan and EMI entries are excluded.")
                            .foregroundStyle(theme.palette.secondaryText)
                    }.padding(.top, theme.spacing.controlGap)
                }.font(theme.typography.body).accessibilityIdentifier("spending.comparisonDetails")
            }
        }
    }

    private func comparisonPrimary(_ value: SpendingComparison) -> some View {
        LFPanel(title: periodName(value.analysis)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recorded spending").font(theme.typography.body).foregroundStyle(theme.palette.secondaryText)
                Text(amount(value.analysis.report.spending)).font(theme.typography.headlineMoney).monospacedDigit()
                Text(spendingChangeSummary(value)).font(theme.typography.rowTitle).monospacedDigit()
                    .foregroundStyle(value.spendingChange > 0 ? LFTheme.warning : theme.palette.primaryText)
                Text("Compared with " + periodName(value.baseline)).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }.accessibilityIdentifier("spending.comparisonAnswer")
            comparisonChart(value).padding(.vertical, 20)
            Divider()
            Text(value.analysis.isPartialCalendarMonth || value.baseline.isPartialCalendarMonth
                 ? "Partial period · recorded transactions only."
                 : "Based on recorded transactions; some records may be missing or need review.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Button("Recorded spending transactions") { onTransactions(spendingIDs(value.analysis.report)) }
                .buttonStyle(.borderless).disabled(spendingIDs(value.analysis.report).isEmpty)
        }
    }

    private func comparisonReview(_ value: SpendingComparison) -> some View {
        let ids = Set(value.analysis.report.rows.filter { $0.treatment == .unresolved }.map(\.id))
        return LFPanel(contentSpacing: 18) {
            Text(ids.isEmpty ? "Review status" : "Needs review").font(theme.typography.secondary).foregroundStyle(ids.isEmpty ? theme.palette.secondaryText : LFTheme.warning)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(ids.count.formatted()).font(theme.typography.headlineMoney).monospacedDigit()
                    .foregroundStyle(ids.isEmpty ? theme.palette.primaryText : LFTheme.warning)
                Text("transactions in this selection").font(theme.typography.body)
            }
            Button("View transactions") { onTransactions(ids) }.lfSecondaryAction().disabled(ids.isEmpty)
            Button("Review financial treatment") { section = "Movement review"; reviewKind = "Needs review" }
                .buttonStyle(.borderless).disabled(ids.isEmpty)
        }
    }

    private func missingComparison(_ value: SpendingComparison) -> some View {
        let missing = value.analysis.report.rows.isEmpty ? value.analysis : value.baseline
        let available = value.analysis.report.rows.isEmpty ? value.baseline : value.analysis
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text(periodName(missing) + " records are not available for this selection.")
                .font(theme.typography.rowTitle)
            if !available.report.rows.isEmpty {
                Text(periodName(available) + " recorded spending").font(theme.typography.body)
                Text(amount(available.report.spending)).font(theme.typography.headlineMoney).monospacedDigit()
            }
            Text("A spending trend cannot yet be established.").font(theme.typography.body)
                .foregroundStyle(theme.palette.secondaryText)
            HStack(spacing: theme.spacing.controlGap) {
                if periodMode == "Calendar months", !value.baseline.report.rows.isEmpty {
                    Button("View " + periodName(value.baseline)) {
                        monthText = String(value.baseline.start.canonical.prefix(7))
                        selectCalendarMonth(); showsComparisonDetails = false; applyDates()
                    }.lfSecondaryAction()
                }
                Button("Review coverage") { showsComparisonDetails = true }.buttonStyle(.borderless)
            }
        }.accessibilityIdentifier("spending.missingComparison")
    }

    private func comparisonChart(_ value: SpendingComparison) -> some View {
        // Shared numeric domain, derived only from the two existing exact projections.
        // Negative recorded spending (for example refunds) retains a signed axis.
        let lower = min(Decimal.zero, value.analysis.report.spending, value.baseline.report.spending)
        let upper = max(Decimal.zero, value.analysis.report.spending, value.baseline.report.spending)
        let domain = geometry(lower)...(lower == upper ? geometry(upper) + 1 : geometry(upper))
        return VStack(alignment: .leading, spacing: 24) {
            comparisonBar(value.baseline, color: theme.palette.secondaryText, domain: domain)
            comparisonBar(value.analysis, color: .cyan, domain: domain)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recorded spending comparison in \(currency)")
        .accessibilityValue("\(periodName(value.baseline)): \(amount(value.baseline.report.spending)); \(periodName(value.analysis)): \(amount(value.analysis.report.spending))")
        .accessibilityIdentifier("spending.comparisonChart")
    }

    private func comparisonBar(_ period: SpendingComparisonPeriod, color: Color, domain: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(periodName(period)).font(theme.typography.body)
                Spacer()
                Text(amount(period.report.spending)).font(theme.typography.rowTitle).monospacedDigit()
            }
            Chart {
                BarMark(xStart: .value("Zero", 0), xEnd: .value("Recorded spending", geometry(period.report.spending)), y: .value("Period", period.title))
                    .foregroundStyle(color).cornerRadius(3)
            }.chartXScale(domain: domain).chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 24)
                .background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: 3))
        }
    }

    @ViewBuilder private func categoryDrivers(_ value: SpendingComparison) -> some View {
        if value.contributors.count == 1 && value.contributors.first?.id == "uncategorized" {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Text("Recorded spending has no categories yet.")
                    .font(theme.typography.body)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.controlGap) { categoryReviewActions(value) }
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) { categoryReviewActions(value) }
                }
            }
        } else if !value.contributors.isEmpty {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                ForEach(value.contributors) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title).font(theme.typography.body.weight(.semibold))
                        Button("Analysis " + amount(item.analysis)) { onTransactions(item.analysisIDs) }.disabled(item.analysisIDs.isEmpty)
                        Button("Comparison " + amount(item.baseline)) { onTransactions(item.baselineIDs) }.disabled(item.baselineIDs.isEmpty)
                        Button("Change " + amount(item.change)) { onTransactions(item.analysisIDs.union(item.baselineIDs)) }
                    }.buttonStyle(.borderless).font(theme.typography.body).monospacedDigit()
                }
                Text("These categories explain the recorded difference, not the reason your spending changed.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        } else {
            Text("No category contributions are established for this comparison.").foregroundStyle(theme.palette.secondaryText)
        }
    }

    @ViewBuilder private func categoryReviewActions(_ value: SpendingComparison) -> some View {
        Button("Review categories") { onTransactions(spendingIDs(value.analysis.report).union(spendingIDs(value.baseline.report))) }.lfSecondaryAction()
        Button("Category rules", action: onCategories).lfSecondaryAction()
    }

    private func spendingChangeSummary(_ value: SpendingComparison) -> String {
        guard value.spendingChange != 0 else { return "No change in recorded spending" }
        let direction = value.spendingChange > 0 ? "higher" : "lower"
        let percent = SpendingComparison.percentage(change: value.spendingChange, baseline: value.baseline.report.spending)
            .map { " · " + ($0 > 0 ? "+" : "") + $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? ""
        return amount(abs(value.spendingChange)) + " " + direction + percent
    }

    private func periodName(_ period: SpendingComparisonPeriod) -> String {
        guard periodMode == "Calendar months" else { return period.title }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        return "\(calendar.monthSymbols[period.start.month - 1]) \(period.start.year)"
    }
    private func comparisonPeriod(_ value: SpendingComparisonPeriod, title: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title + " · " + value.title).font(theme.typography.formSection)
            if value.report.rows.isEmpty { Text("No observed transactions in this scope. Zero recorded totals do not establish zero activity.").foregroundStyle(LFTheme.warning) }
            Button("Recorded income: " + amount(value.report.income)) { onTransactions(recognizedIDs(value.report, treatment: .income)) }.buttonStyle(.borderless)
            Button("Recorded spending: " + amount(value.report.spending)) { onTransactions(spendingIDs(value.report)) }.buttonStyle(.borderless)
            Button("\(value.purchaseIDs.count) purchases · average " + (value.averagePurchase.map(averageAmount) ?? "unavailable")) { onTransactions(value.purchaseIDs) }
                .buttonStyle(.borderless).disabled(value.purchaseIDs.isEmpty)
            Button("Fees / interest " + amount(value.chargeAmount)) { onTransactions(value.chargeIDs) }.buttonStyle(.borderless).disabled(value.chargeIDs.isEmpty)
            let refunds = value.report.rows.filter { $0.treatment == .refund }
            Button("Refunds " + amount(refunds.reduce(0) { $0 + $1.spending })) { onTransactions(Set(refunds.map(\.id))) }.buttonStyle(.borderless).disabled(refunds.isEmpty)
            let unresolved = value.report.rows.filter { $0.treatment == .unresolved }
            Button("\(unresolved.count) need review · " + amount(unresolved.reduce(0) { $0 + $1.source.amount }) + " before offsets") {
                onTransactions(Set(unresolved.map(\.id)))
            }.buttonStyle(.borderless).disabled(unresolved.isEmpty)
            let excluded = value.report.rows.filter { ![.income, .expense, .refund, .unresolved].contains($0.treatment) }
            Button("\(excluded.count) transfers, settlements or financing entries excluded · " + amount(excluded.reduce(0) { $0 + $1.source.amount }) + " gross") {
                onTransactions(Set(excluded.map(\.id)))
            }.buttonStyle(.borderless).disabled(excluded.isEmpty)
            DisclosureGroup("Source coverage · \(value.coverage.filter { !$0.complete }.count) accounts incomplete") {
                ForEach(value.coverage) { item in
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(item.title).font(theme.typography.body)
                        Text("Recorded through " + (item.recordedThrough?.presentation ?? "unknown") + (item.complete ? " · period covered" : " · selected period has gaps"))
                    }
                }
                Text("Coverage comes from source periods. Classification uncertainty is shown separately above. Missing or unreviewed data is not zero.")
            }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            DisclosureGroup("Unrounded amounts") {
                Text("Income \(exact(value.report.income)) · Spending \(exact(value.report.spending))")
                Text("Average purchase " + (value.averagePurchase.map(exact) ?? "unavailable"))
            }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }
    private func difference(_ title: String, _ change: Decimal, baseline: Decimal, ids: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(title + ": " + exact(change)) { onTransactions(ids) }.buttonStyle(.borderless).disabled(ids.isEmpty)
            if let percent = SpendingComparison.percentage(change: change, baseline: baseline) {
                Text(percent.formatted(.number.precision(.fractionLength(1))) + "% of the comparison total")
            } else { Text("Percentage unavailable: comparison total is zero or negative.") }
        }.font(theme.typography.formCaption)
    }
    private func recognizedIDs(_ value: SpendingProjection, treatment: SpendingTreatment) -> Set<String> { Set(value.rows.filter { $0.treatment == treatment }.map(\.id)) }
    private func spendingIDs(_ value: SpendingProjection) -> Set<String> { Set(value.rows.filter { $0.treatment == .expense || $0.treatment == .refund }.map(\.id)) }
    private func exact(_ value: Decimal) -> String {
        currency + " " + value.formatted(.number.precision(.fractionLength(2...8)).locale(Locale(identifier: currency == "INR" ? "en_IN" : "en_US")))
    }
    private func averageAmount(_ value: Decimal) -> String {
        // An average can have sub-minor-unit precision. Round a display copy;
        // the comparison's original Decimal remains untouched.
        var source = value, rounded = Decimal()
        NSDecimalRound(&rounded, &source, MoneyFormatting.displayFractionDigits, .plain)
        return amount(rounded)
    }
    @ViewBuilder private func movements(_ value: SpendingProjection) -> some View {
        let layout = contentWidth >= 1080 ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        layout {
            Picker("Review", selection: $reviewKind) {
                ForEach(["Suggestions", "Needs review", "Confirmed", "Dismissed"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 650)
            Button("Review selected transactions…") { selection = .init(event: nil, suggested: nil, selectedIDs: [], kind: .ownTransfer) }.lfSecondaryAction()
        }
        Text("Review suggestions before linking entries.")
            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        if reviewKind == "Suggestions" {
            if value.suggestions.isEmpty { ContentUnavailableView("No movement suggestions in this selection", systemImage: "arrow.left.arrow.right") }
            let groups = SpendingIntelligence.suggestionGroups(value.suggestions)
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groups.prefix(reviewLimit)) { group in
                    LFPanel(contentSpacing: 12) {
                        if group.suggestions.count == 1, let suggestion = group.suggestions.first {
                            suggestionHeading(suggestion)
                            legs(group.transactionIDs.sorted())
                            suggestionEvidence(suggestion)
                        } else {
                            Text("\(group.suggestions.count) alternatives sharing these entries").font(theme.typography.rowTitle)
                            legs(group.transactionIDs.sorted())
                            Text("One decision: these alternatives share at least one entry. Review the complete reference and source roles before choosing.")
                                .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                            ForEach(group.suggestions) { suggestion in
                                Divider()
                                suggestionHeading(suggestion)
                                Text(candidateAccounts(suggestion)).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                suggestionEvidence(suggestion)
                            }
                        }
                    }
                }
            }
            if groups.count > reviewLimit { Button("Show more decisions") { reviewLimit += 40 }.lfSecondaryAction() }
        } else if reviewKind == "Needs review" {
            let unresolved = value.rows.filter { $0.treatment == .unresolved }
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(unresolved.prefix(reviewLimit)) { row in
                    LFPanel(contentSpacing: 12) {
                        HStack {
                            Text("Needs review").font(theme.typography.rowTitle)
                            Spacer()
                            Button("Review") { selection = .init(event: nil, suggested: nil, selectedIDs: [row.id], kind: row.source.isBankIn ? .income : .expense) }.lfSecondaryAction()
                        }
                        sourceRow(row.source)
                        Text(row.explanation).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                }
            }
            if unresolved.isEmpty { Text("No transactions need review in this selection.").foregroundStyle(theme.palette.secondaryText) }
            if unresolved.count > reviewLimit { Button("Show more entries") { reviewLimit += 40 }.lfSecondaryAction() }
        } else {
            let hiddenHistoryRows = Set(model.sourceRows.filter { !relationshipHistoryScope.includes($0.accountID) }.map(\.id))
            let events = store.snapshot?.movements.filter { $0.decision == (reviewKind == "Confirmed" ? .confirmed : .rejected)
                && $0.transactionIDs.contains(where: Set(value.rows.map(\.id)).contains)
                && $0.transactionIDs.allSatisfy { !hiddenHistoryRows.contains($0) } } ?? []
            if events.isEmpty { Text("No \(reviewKind.lowercased()) relationships in this selection.").foregroundStyle(theme.palette.secondaryText) }
            ForEach(events) { event in
                LFPanel(contentSpacing: 12) {
                    HStack {
                        Text(event.kind.title).font(theme.typography.rowTitle)
                        Spacer()
                        if event.kind.isInScope {
                            Button("Edit") { selection = .init(event: event, suggested: nil, selectedIDs: Set(event.transactionIDs), kind: event.kind) }.lfSecondaryAction()
                            Button(event.decision == .confirmed ? "Unlink" : "Revisit") { request { perform { guard let generation else { throw FinancialIntelligenceError.unavailable }; try FinancialIntelligenceCoordinator().removeMovement(event, generation: generation) } } }.lfSecondaryAction()
                        } else {
                            Text("Saved decision · outside this selection").font(theme.typography.secondary)
                        }
                    }
                    legs(event.transactionIDs)
                    Text(event.explanation).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    if let conflict = SpendingIntelligence.contradiction(event, rows: model.sourceRows, sources: store.sources) {
                        Text(conflict).foregroundStyle(LFTheme.warning)
                    }
                }
            }
        }
    }

    private func suggestionHeading(_ suggestion: MovementSuggestion) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(suggestion.tentativeTitle).font(theme.typography.rowTitle)
            Spacer(minLength: 12)
            Button("Review") { selection = .init(event: nil, suggested: suggestion, selectedIDs: Set(suggestion.transactionIDs), kind: suggestion.kind) }
                .lfSecondaryAction().accessibilityIdentifier("movements.review.\(suggestion.id)")
            Button("Dismiss") { dismiss(suggestion) }
                .lfSecondaryAction().accessibilityIdentifier("movements.dismiss.\(suggestion.id)")
        }
    }

    private func suggestionEvidence(_ suggestion: MovementSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(suggestion.explanation).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if let warning = suggestion.routeWarning { Text(warning).font(theme.typography.secondary).foregroundStyle(LFTheme.warning) }
        }
    }

    private var relationshipHistoryScope: AccountPresentationScope {
        .init(selectedAccountIDs: [],
            historyOnlyAccountIDs: Set(store.sources.accounts.filter(\.isHistoryOnly).map(\.id))
                .subtracting(accountID.isEmpty ? [] : [accountID]))
    }

    private func legs(_ ids: [String]) -> some View {
        let selected = Set(ids)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(model.sourceRows.filter { selected.contains($0.id) }) { sourceRow($0) }
            if model.sourceRows.contains(where: { selected.contains($0.id) && $0.currency != currency }) {
                Text("Linked entries in other currencies are shown for this review.").font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }
    private func sourceRow(_ row: SpendingSourceRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if contentWidth >= 1050 {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(row.date?.presentation ?? "Date unavailable").font(theme.typography.secondary)
                        .frame(width: 100, alignment: .leading).help(row.dateRole)
                    movementAccount(row)
                        .font(theme.typography.body.weight(.semibold)).frame(width: 240, alignment: .leading)
                    Text(row.transaction.description).font(theme.typography.body).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading).help(row.transaction.description)
                    movementAmount(row)
                    inspectEntry(row)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    movementAccount(row)
                        .font(theme.typography.body.weight(.semibold))
                    Spacer()
                    movementAmount(row)
                    inspectEntry(row)
                }
                Text(row.date?.presentation ?? "Date unavailable").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText).help(row.dateRole)
                Text(row.transaction.description).font(theme.typography.body).lineLimit(2).help(row.transaction.description)
            }
        }.padding(.vertical, 3)
    }

    private func movementAmount(_ row: SpendingSourceRow) -> some View {
        Text(row.exactAmount).font(theme.typography.tableMoney).monospacedDigit().fixedSize()
            .foregroundStyle(row.transaction.money.amount == 0 ? theme.palette.primaryText : ((row.isBankOut || row.transaction.cardLiabilityEffect == .increasesAmountOwed) ? LFTheme.danger : (row.isBankIn || row.transaction.cardLiabilityEffect == .decreasesAmountOwed) ? LFTheme.success : theme.palette.primaryText))
    }

    private func movementAccount(_ row: SpendingSourceRow) -> some View {
        let account = store.sources.accounts.first { $0.id == row.accountID }
        return LFAccountLabel(title: account?.title ?? row.accountTitle, detail: account?.selectionContext ?? row.currency)
    }

    private func inspectEntry(_ row: SpendingSourceRow) -> some View {
        Button { onTransactions([row.id]) } label: { Image(systemName: "arrow.up.right.square") }
            .buttonStyle(.borderless).help("Inspect the original transaction").accessibilityLabel("Inspect original transaction")
            .accessibilityIdentifier("movements.inspect.\(row.id)")
    }
    private func candidateAccounts(_ suggestion: MovementSuggestion) -> String {
        model.sourceRows.filter { suggestion.transactionIDs.contains($0.id) }.map { row in
            store.sources.accounts.first { $0.id == row.accountID }?.title ?? row.accountTitle
        }.joined(separator: " ↔ ")
    }
    private func refresh() {
        // Keep local filters for Back navigation, but do not analyze canonical
        // revisions while the retained chart view is hidden.
        guard isActive else { model.cancel(); return }
        reviewLimit = 40
        guard usable else { model.clear(); return }
        model.refresh(generation: generation, currency: currency, accountID: accountID,
            start: try? StatementDate(canonical: appliedStart), end: try? StatementDate(canonical: appliedEnd),
            baselineStart: try? StatementDate(canonical: appliedBaselineStart), baselineEnd: try? StatementDate(canonical: appliedBaselineEnd))
    }
    private func amount(_ value: Decimal) -> String {
        (try? Money(amount: value, currency: currency)).map { MoneyFormatting.display($0) } ?? "Unavailable"
    }
    private func axisAmount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: currency == "INR" ? "en_IN" : "en_US")))
    }
    private func axisMonth(_ value: String) -> String {
        guard let month = try? SelectedStatementMonth(canonical: value) else { return value }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        return "\(calendar.shortMonthSymbols[month.month - 1])\n\(month.year)"
    }
    private func geometry(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private func dismiss(_ suggestion: MovementSuggestion) {
        request { perform {
            guard let generation, let metadata = store.snapshot else { throw FinancialIntelligenceError.unavailable }
            let event = MovementEvent(id: suggestion.id, workspaceID: metadata.workspaceID, kind: suggestion.kind, decision: .rejected,
                transactionIDs: suggestion.transactionIDs, explanation: suggestion.explanation, reviewedAtISO: ISO8601DateFormatter().string(from: Date()))
            try FinancialIntelligenceCoordinator().saveMovement(event, replacing: nil, generation: generation)
        } }
    }
    private func perform(_ action: () throws -> Void) { do { try action(); message = nil } catch { message = error.localizedDescription } }
    private func request(_ action: @escaping () -> Void) {
#if DEBUG
        do { if let generation { try DevelopmentProfileAcknowledgementGate.shared.requireAuthorization(for: .financialIntelligenceMutation, providerGeneration: generation) } }
        catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) { challenge = value; pending = action; return }
        catch { message = error.localizedDescription; return }
#endif
        action()
    }
}

private struct MovementReviewDraft: Identifiable {
    let id = UUID()
    let event: MovementEvent?
    let suggested: MovementSuggestion?
    var selectedIDs: Set<String>
    var kind: MovementKind
}

private struct MovementReviewEditor: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let draft: MovementReviewDraft
    let rows: [SpendingSourceRow]
    let generation: ProviderGenerationToken?
    let sources: FinancialSourceContext
    let historyScope: AccountPresentationScope
    @State private var ids: Set<String> = []
    @State private var kind: MovementKind = .ownTransfer
    @State private var explanation = ""
    @State private var search = ""
    @State private var message: String?
    @State private var acknowledgement = false
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
#endif
    private var selected: [SpendingSourceRow] { rows.filter { ids.contains($0.id) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Review financial meaning").font(theme.typography.formTitle); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            Picker("Meaning", selection: $kind) { ForEach(MovementKind.allCases.filter(\.isInScope), id: \.self) { Text($0.title).tag($0) } }.frame(maxWidth: 380)
            Text(meaning).font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(selected) { row in
                        HStack(alignment: .top) {
                            Button { ids.remove(row.id) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).help("Remove this leg from the review")
                            rowLabel(row)
                        }
                    }
                    if let warning { Text(warning).foregroundStyle(LFTheme.warning) }
                    if let ratio { Text(ratio).font(theme.typography.formCaption) }
                }
            }.frame(minHeight: 90, maxHeight: 230)
            TextField("Reason for this interpretation", text: $explanation, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            Divider()
            TextField("Find an original entry by narration, reference or account", text: $search).textFieldStyle(.roundedBorder)
            if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                ScrollView { LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(matches.prefix(80)) { row in
                        HStack { Button { ids.insert(row.id) } label: { Image(systemName: "plus.circle") }.buttonStyle(.borderless).disabled(ids.contains(row.id)); rowLabel(row) }
                    }
                    if matches.count > 80 { Text("Narrow the search to see more specific entries.").foregroundStyle(theme.palette.secondaryText) }
                } }.frame(minHeight: 100, maxHeight: 230)
            }
            Toggle("I have checked the source entries and their financial meaning", isOn: $acknowledgement).toggleStyle(.checkbox)
            if let message { Text(message).foregroundStyle(LFTheme.warning) }
            HStack { Spacer(); Button("Confirm interpretation", action: requestSave).buttonStyle(.borderedProminent).disabled(!acknowledgement || ids.isEmpty || explanation.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
        .padding(24).frame(minWidth: 850, idealWidth: 1100, minHeight: 500, idealHeight: 700)
        .foregroundStyle(theme.palette.primaryText).background(theme.palette.contentSurface)
        .onAppear { ids = draft.selectedIDs; kind = draft.kind; explanation = draft.event?.explanation ?? draft.suggested?.explanation ?? "" }
        .onChange(of: kind) { _, _ in acknowledgement = false }
        .onChange(of: ids) { _, _ in acknowledgement = false }
#if DEBUG
        .alert(DevelopmentProfileAcknowledgementPresentation.title, isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil } })) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) { if let challenge { _ = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) }; challenge = nil; save() }
            Button("Cancel", role: .cancel) { challenge = nil }
        } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }
    private var meaning: String {
        switch kind {
        case .ownTransfer: "Both bank entries remain. Neither is income or spending; cross-currency amounts keep their original currencies."
        case .cardPayment: "Bank cash pays down the card liability. This is a cash commitment, not another purchase."
        case .refund: "The credit reduces spending on its source date. Select the original purchase too when its identity is established."
        case .reversal: "These equal, opposite entries cancel one another. Separate fees still count as spending."
        case .borrowing, .emiConversion: "Loan and EMI analysis is outside the selected scope."
        case .expense: "This one original outgoing entry is spending, separate from its category."
        case .income: "This one original bank credit is external income. Transfers and borrowed funds must not be labelled income."
        }
    }
    private var warning: String? {
        let types = Dictionary(uniqueKeysWithValues: sources.accounts.map { ($0.id, $0.routeType) })
        return kind == .ownTransfer && selected.contains(where: { $0.isBankOut && types[$0.accountID] == "NRO" }) && selected.contains(where: { $0.isBankIn && types[$0.accountID] == "NRE" })
            ? "NRO to NRE contradicts your selected transfer routes. Check these entries before confirming." : nil
    }
    private var ratio: String? {
        guard kind == .ownTransfer, selected.count == 2, let out = selected.first(where: \.isBankOut), let incoming = selected.first(where: \.isBankIn), out.currency != incoming.currency, out.amount > 0 else { return nil }
        return "Observed legs: 1 \(out.currency) to \((incoming.amount / out.amount).formatted(.number.precision(.fractionLength(4)))) \(incoming.currency). This ratio does not separate exchange rate and fees."
    }
    private var matches: [SpendingSourceRow] {
        let words = search.uppercased().split(separator: " ")
        return rows.filter { row in let text = row.text + " " + row.accountTitle.uppercased(); return historyScope.includes(row.accountID) && !row.isLoanOrEMI && words.allSatisfy { text.contains($0) } }.sorted { ($0.date?.canonical ?? "", $0.id) > ($1.date?.canonical ?? "", $1.id) }
    }
    private func rowLabel(_ row: SpendingSourceRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(sources.accounts.first { $0.id == row.accountID }?.title ?? row.accountTitle); Text(row.date?.presentation ?? "Date unavailable"); Text(row.exactAmount).monospacedDigit() }.font(theme.typography.formSection)
            Text(row.transaction.description).font(theme.typography.formCaption).textSelection(.enabled)
            Text(row.dateRole + (row.transaction.reference.map { " · Reference " + $0 } ?? "")).font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func requestSave() {
#if DEBUG
        do { if let generation { try DevelopmentProfileAcknowledgementGate.shared.requireAuthorization(for: .financialIntelligenceMutation, providerGeneration: generation) } }
        catch DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) { challenge = value; return }
        catch { message = error.localizedDescription; return }
#endif
        save()
    }
    private func save() {
        do {
            guard kind.isInScope, !selected.contains(where: \.isLoanOrEMI) else { throw FinancialIntelligenceError.outsideScope }
            guard let generation, let metadata = FinancialIntelligenceStore.shared.snapshot else { throw FinancialIntelligenceError.unavailable }
            let event = MovementEvent(id: draft.event?.id ?? draft.suggested?.id ?? UUID().uuidString, workspaceID: metadata.workspaceID,
                kind: kind, decision: .confirmed, transactionIDs: ids.sorted(), explanation: explanation,
                reviewedAtISO: ISO8601DateFormatter().string(from: Date()))
            try FinancialIntelligenceCoordinator().saveMovement(event, replacing: draft.event, generation: generation)
            dismiss()
        } catch { message = error.localizedDescription }
    }
}
