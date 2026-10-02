import SwiftUI
import Charts
import Combine
import CryptoKit

private struct ReserveProgressChart: View {
    @Environment(\.lfTheme) private var theme
    let values: [ReserveProgress]
    let currency: String
    private var maximum: Double {
        max(1, (values.flatMap { [$0.target, $0.fundedAfterBills ?? 0] }.map(numeric).max() ?? 1) * 1.35)
    }
    private func numeric(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private func amount(_ value: Decimal) -> String {
        (try? Money(amount: value, currency: currency)).map { MoneyFormatting.display($0) } ?? "Unavailable"
    }
    private func bar(_ amountValue: Decimal, reserve: ReserveProgress, measure: String) -> some ChartContent {
        BarMark(x: .value("Amount", numeric(amountValue)), y: .value("Reserve", reserve.id), height: .fixed(14))
            .foregroundStyle(by: .value("Measure", measure))
            .position(by: .value("Measure", measure))
            .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                Text(amount(amountValue)).font(theme.typography.body.weight(.semibold)).monospacedDigit().fixedSize()
                    .foregroundStyle(measure == "Target" ? theme.palette.primaryText : Color.cyan)
            }
            .accessibilityLabel(reserve.designation.title + ", " + measure + " " + amount(amountValue))
    }
    var body: some View {
        Chart(values) { value in
            bar(value.target, reserve: value, measure: "Target")
            if let funded = value.fundedAfterBills {
                bar(funded, reserve: value, measure: "Conditional funding")
            }
        }
        .chartForegroundStyleScale(["Target": theme.palette.secondaryText.opacity(0.7), "Conditional funding": Color.cyan])
        .chartXScale(domain: 0...maximum)
        .chartYScale(domain: values.map(\.id))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let id = value.as(String.self), let reserve = values.first(where: { $0.id == id }) {
                        Text(reserve.designation.title).font(theme.typography.body)
                    }
                }
            }
        }
        .frame(height: CGFloat(max(1, values.count)) * 78 + 40)
        // A target and its funding are separate measures, never an additive
        // total. Supply the same named values instead of Charts' grouped sum.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reserve targets and conditional funding in \(currency)")
        .accessibilityValue(values.map { value in
            "\(value.designation.title): target \(amount(value.target)); conditional funding \(value.fundedAfterBills.map(amount) ?? "unknown")"
        }.joined(separator: ". "))
    }
}

/// Hover state stays local to the chart, so inspecting a value does not rerun
/// account analysis or rebuild the surrounding planning workspace.
private struct RunwayBalanceChart: View {
    @Environment(\.lfTheme) private var theme
    let runway: AccountRunway
    @State private var hoveredDay: StatementDate?

    private var dayEnds: [PlanningBalancePoint] {
        let last = Dictionary(grouping: runway.points, by: \.date).compactMapValues(\.last)
        return last.values.sorted { $0.date < $1.date }
    }
    private var inspectedPoint: PlanningBalancePoint? {
        guard let hoveredDay else { return nil }
        return runway.points.last { $0.date <= hoveredDay }
    }
    private func amount(_ value: Decimal) -> String {
        (try? Money(amount: value, currency: runway.anchor.currency)).map { MoneyFormatting.display($0) } ?? "Unavailable"
    }
    private func numeric(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let point = inspectedPoint, let hoveredDay {
                    Text(hoveredDay.presentation).font(theme.typography.body)
                    Text(amount(point.balance)).font(theme.typography.rowTitle).monospacedDigit()
                    Text(point.isForecast ? "Projected balance" : "Recorded balance").foregroundStyle(theme.palette.secondaryText)
                } else {
                    Text("Move the pointer over the chart to inspect a balance")
                        .foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Text("Protected: " + amount(runway.reserveFloor)).foregroundStyle(theme.palette.secondaryText)
            }.font(theme.typography.secondary).frame(minHeight: 30)
            Chart {
                ForEach(runway.points) { point in
                    if let date = FinancialCalendar.instant(point.date) {
                        LineMark(x: .value("Date", date), y: .value("Balance", numeric(point.balance)))
                            .interpolationMethod(.stepEnd).lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 4])).foregroundStyle(Color.cyan)
                        PointMark(x: .value("Date", date), y: .value("Balance", numeric(point.balance)))
                            .symbolSize(point.isForecast ? 30 : 55).foregroundStyle(point.isForecast ? Color.cyan : theme.palette.primaryText)
                    }
                }
                ForEach(dayEnds) { point in
                    if dayEnds.count <= 8 || point.id == dayEnds.last?.id,
                       let date = FinancialCalendar.instant(point.date) {
                        PointMark(x: .value("Date", date), y: .value("Balance", numeric(point.balance)))
                            .symbolSize(1).foregroundStyle(.clear)
                            .annotation(position: .top, alignment: point.id == dayEnds.first?.id ? .leading : point.id == dayEnds.last?.id ? .trailing : .center) {
                                Text(amount(point.balance)).font(theme.typography.body.weight(.semibold))
                                    .monospacedDigit().foregroundStyle(theme.palette.primaryText)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(theme.palette.raisedSurface, in: RoundedRectangle(cornerRadius: 5))
                            }
                    }
                }
                RuleMark(y: .value("Protected balance", numeric(runway.reserveFloor)))
                    .foregroundStyle(theme.palette.secondaryText).lineStyle(StrokeStyle(dash: [2, 4]))
                RuleMark(y: .value("Zero", 0)).foregroundStyle(LFTheme.warning.opacity(0.7))
                if let hoveredDay, let date = FinancialCalendar.instant(hoveredDay), let point = inspectedPoint {
                    RuleMark(x: .value("Selected date", date)).foregroundStyle(theme.palette.primaryText.opacity(0.5))
                    PointMark(x: .value("Date", date), y: .value("Balance", numeric(point.balance)))
                        .symbolSize(65).foregroundStyle(theme.palette.primaryText)
                }
            }
            .chartXScale(range: .plotDimension(padding: 12))
            .chartYScale(range: .plotDimension(padding: 26))
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, calendar: FinancialCalendar.calendar)) { value in
                    AxisGridLine(); AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(AppDateDisplay.date(date, zone: TimeZone(secondsFromGMT: 0)!)).font(theme.typography.caption)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let anchor = proxy.plotFrame else { hoveredDay = nil; return }
                                let frame = geometry[anchor]
                                guard frame.contains(location), let date = proxy.value(atX: location.x - frame.minX, as: Date.self) else { hoveredDay = nil; return }
                                let day = FinancialCalendar.statement(date)
                                if hoveredDay != day { hoveredDay = day }
                            case .ended: hoveredDay = nil
                            }
                        }
                }
            }
            .frame(height: 290)
            .accessibilityLabel("Conditional \(runway.anchor.currency) account balance. Exact dates and values follow below.")
        }
    }
}

struct PlanningInsightsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var planner: SalaryWorkspaceViewModel
    @Binding var selection: SalaryWorkspaceViewModel.InsightSelection
    @ObservedObject private var store = FinancialIntelligenceStore.shared
    @ObservedObject private var salarySession = SalaryAssistanceSession.shared
    @ObservedObject var model: PlanningAnalysisModel
    let onTransactions: (Set<String>) -> Void
    let onMonthlyPlan: () -> Void
    var availableWidth: CGFloat = 1000
    private var columnLayout: AnyLayout {
        availableWidth >= 820 ? AnyLayout(HStackLayout(alignment: .top, spacing: 24)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
    }
    private var section: String { selection.section }
    private var accountID: String { get { selection.accountID } nonmutating set { selection.accountID = newValue } }
    private var currency: String { selection.currency }
    private var scenario: PlanningScenario { get { selection.scenario } nonmutating set { selection.scenario = newValue } }
    @State private var editor: PlanningEditorRequest?
    @State private var message: String?
    @State private var showAssumptions = false
    @State private var expandedCommitmentID: String?
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pending: (() -> Void)?
#endif
    private var metadata: FinancialIntelligenceSnapshot? { store.snapshot }
    private var accounts: [IntelligenceAccountContext] {
        store.sources.accounts.filter { $0.domain == "bank" }
    }
    private var availableAccountIDs: Set<String> {
        Set(planner.availablePlanningAccounts.compactMap(\.repositoryAccountId)).subtracting(planner.excludedPlanningAccountIDs)
    }
    private var assistance: PlanAssistance { planner.plan.assistance ?? .init(workspaceID: planner.plan.workspaceID, month: planner.month.canonical) }
    private var usable: Bool { planner.canEdit && store.generation == planner.generation && metadata != nil }
    private var selectedRunway: AccountRunway? { model.projection?.runways.first { $0.id == accountID } ?? model.projection?.runways.first }
    private var changeSections: [String: String] {
        func digest<T: Encodable>(_ value: T) -> String {
            let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
            return SHA256.hash(data: (try? encoder.encode(value)) ?? Data()).map { String(format: "%02x", $0) }.joined()
        }
        return [
            "Salary proposals": digest(metadata?.salaries.map { $0.id + $0.draftState.rawValue }.sorted() ?? []),
            "Payment matches": digest(metadata?.occurrences ?? []),
            "Commitments": digest(metadata?.recurring ?? []),
            "Reserve targets": digest(metadata?.reserves ?? []),
            "Category rules": digest(CategoryStore.shared.snapshot.automation?.rules ?? []),
            "Statement coverage": digest(store.sources.periods.map { $0.accountID + $0.start.canonical + $0.end.canonical }.sorted()),
            "Account balances": digest(AccountStore.shared.accounts.map { ($0.repositoryAccountId ?? "") + ($0.currentBalanceAsOfISO ?? "unknown") + ($0.currentBalanceAsOfISO == nil ? "unknown" : NSDecimalNumber(decimal: $0.currentBalance).stringValue) }.sorted())
        ]
    }
    private var changeKey: String {
        changeSections.sorted { $0.key < $1.key }.map { $0.key + $0.value }.joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let message { Text(message).foregroundStyle(LFTheme.warning).textSelection(.enabled) }
            if !usable {
                Text("Planning context is unavailable or this draft belongs to an older ledger. Reload the plan before editing.").foregroundStyle(LFTheme.warning)
            } else if let value = model.projection {
                if section == "Cash runway" { runway(value) }
                else if section == "Commitments" { LFPanel { commitments(value) } }
                else { LFPanel { reserves(value) } }
                LFPanel(contentSpacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        insightNavigation
                        VStack(alignment: .leading, spacing: 10) {
                            insightSections
                            insightTools
                        }
                    }
                    DisclosureGroup("Planning setup and changes") {
                        if let issue = SpendingIntelligence.salarySetupIssue(preferences: metadata?.preferences, categories: CategoryStore.shared.snapshot, sources: store.sources) {
                            Text(issue).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                            Button("Set up salary assistance") { editor = .preferences }.lfSecondaryAction()
                        }
                        if metadata?.preferences?.lastReviewedChangeKey != changeKey { changes }
                        else { Text("Recorded planning changes reviewed.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText) }
                    }
                }
            } else if model.isWorking {
                ProgressView("Preparing account context…")
            } else {
                Text("Planning analysis is unavailable. Review account funding and reload the plan.").foregroundStyle(LFTheme.warning)
                Button("Review account funding") { editor = .funding }.lfSecondaryAction()
            }
            if model.isWorking { ProgressView().controlSize(.small).accessibilityLabel("Updating planning analysis") }
        }
        .font(theme.typography.body)
        .foregroundStyle(theme.palette.primaryText)
        .onAppear { refresh() }
        .onDisappear { model.cancel() }
        .onChange(of: planner.plan) { _, _ in refresh() }
        .onChange(of: planner.selectedHistoryAccountIDs) { _, _ in refresh() }
        .onChange(of: planner.retainedRecurringOccurrenceIDs) { _, _ in refresh() }
        .onChange(of: planner.recurringOccurrenceExclusions) { _, _ in refresh() }
        .onChange(of: store.revision) { _, _ in refresh() }
        .onChange(of: scenario) { _, _ in refresh() }
        .onChange(of: model.isWorking) { _, working in
            if !working, model.projection?.runways.contains(where: { $0.id == accountID }) != true {
                accountID = model.projection?.runways.first?.id ?? ""
            }
        }
        .sheet(item: $editor) { request in
            PlanningEditorView(request: request, metadata: metadata, accounts: accounts, availableAccountIDs: availableAccountIDs, excludedHistoryAccountIDs: planner.excludedHistoryAccountIDs, rows: model.rows, plan: planner.plan,
                onMetadata: { edit in try FinancialIntelligenceCoordinator().applyPlanning(edit, generation: planner.generation) },
                onAssistance: { planner.updateAssistance($0); editor = nil },
                onSalary: { value in
                    guard let row = model.rows.first(where: { $0.id == value.id }), let month = try? SelectedStatementMonth(canonical: value.targetMonth) else { return }
                    guard planner.month == month else { return }
                    planner.applySalary(value, source: row)
                    editor = nil; onMonthlyPlan()
                }, onPrefills: { planner.applyRecurring($0); editor = nil; onMonthlyPlan() })
        }
#if DEBUG
        .alert(DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pending = nil } })) {
                Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                    if let challenge { _ = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) }
                    let action = pending; pending = nil; challenge = nil; action?()
                }
                Button("Cancel", role: .cancel) { pending = nil; challenge = nil }
            } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }

    private var insightNavigation: some View {
        HStack(spacing: 16) { insightSections; Spacer(minLength: 8); insightTools }
    }
    private var insightSections: some View {
        Picker("Planning insight", selection: $selection.section) {
            Text("Balance forecast").tag("Cash runway")
            Text("Commitments").tag("Commitments")
            Text("Reserves").tag("Reserves")
        }.pickerStyle(.segmented).frame(maxWidth: 480)
    }
    private var insightTools: some View {
        HStack(spacing: 12) {
            Button("Salary assistance") { editor = .preferences }.buttonStyle(.link)
            Button("Account funding") { editor = .funding }.buttonStyle(.link)
            Button("Plan assumptions") { editor = .budget }.buttonStyle(.link)
        }
    }

    private var changes: some View {
        let reviewedSections = changeSections, reviewedKey = changeKey
        let reviewedGeneration = planner.generation, reviewedRevision = store.revision
        let reviewedMetadata = metadata
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("What changed", systemImage: "arrow.triangle.2.circlepath").font(theme.typography.body.weight(.semibold))
                Spacer()
                Button("Mark reviewed") {
                    guard let metadata = reviewedMetadata else { return }
                    var value = metadata.preferences ?? .init(workspaceID: metadata.workspaceID)
                    value.lastReviewedChangeKey = reviewedKey
                    value.lastReviewedSections = reviewedSections
                    mutate { try FinancialIntelligenceCoordinator().acknowledgePlanningReview(value, replacing: metadata.preferences,
                        generation: reviewedGeneration, revision: reviewedRevision) }
                }.lfSecondaryAction()
            }
            let pending = metadata?.salaries.filter { $0.draftState == .proposed || $0.draftState == .reviewed } ?? []
            let changed = reviewedSections.keys.filter { reviewedMetadata?.preferences?.lastReviewedSections?[$0] != reviewedSections[$0] }.sorted()
            if reviewedMetadata?.preferences?.lastReviewedSections == nil {
                Text("First review: no earlier reviewed state is saved for comparison. Check the available planning context before marking it reviewed.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            } else {
                Text("Updated areas: " + changed.joined(separator: ", ") + ". These areas have different recorded state; a detailed change history is not available.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Button("Review historical salary credits") { editor = .historicalSalary }.lfSecondaryAction()
            if pending.isEmpty {
                Text("Review statement coverage, payment matches and rule changes before relying on the updated plan.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            ForEach(pending) { salary in
                HStack {
                    Text("Salary received \(AppDateDisplay.civil(salary.financialDate)) · draft for \(AppDateDisplay.month(salary.targetMonth))")
                    Spacer()
                    Button("Review proposal") {
                        guard let month = try? SelectedStatementMonth(canonical: salary.targetMonth) else { return }
                        planner.switchMonth(to: month)
                        guard planner.month == month, planner.canEdit else { message = "Reload the target month before reviewing this proposal."; return }
                        editor = .salary(salary)
                    }.lfSecondaryAction()
                }
            }
            if let status = salarySession.message { Text(status).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText) }
        }.padding(14).background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
    }

    private func runway(_ projection: PlanningProjection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let value = selectedRunway {
                let capacity = projection.investmentCapacity(accountID: value.id, assistance: assistance)
                LFPanel(contentSpacing: 10) {
                    columnLayout {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Additional investment capacity").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            Text(capacity.0.map { amount($0, value.anchor.currency) } ?? "Unavailable")
                                .font(theme.typography.headlineMoney).monospacedDigit()
                                .foregroundStyle(capacity.0 == nil || (capacity.0 ?? 0) < 0 ? LFTheme.warning : theme.palette.primaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(capacity.1.first ?? "Based on the included cash flows and protected balances.")
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Review funding and actuals") { editor = .funding }.lfSecondaryAction()
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                LFPanel(title: "Balance forecast", contentSpacing: 14) {
                    columnLayout {
                        VStack(alignment: .leading, spacing: 7) {
                            LFAccountPicker(label: "Selected account", placeholder: "Choose account", selection: $selection.accountID,
                                options: projection.runways.map { item in
                                    .init(id: item.id, title: accounts.first { $0.id == item.id }?.title ?? item.anchor.title,
                                        detail: accounts.first { $0.id == item.id }?.selectionContext ?? item.anchor.currency)
                                }, allowsEmptySelection: false)
                                .accessibilityLabel("Forecast account")
                            Text("Currency: \(value.anchor.currency)").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        figure("Starting balance", value.anchor.amount, currency: value.anchor.currency,
                               detail: value.anchor.date.map { "Balance date: " + $0.presentation } ?? "Balance date unavailable")
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Forecast period").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            Text("\(projection.start.presentation)–\(projection.end.presentation)")
                            Text("90 days").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    if value.anchor.amount == nil || value.anchor.date == nil {
                        Text("A dated starting balance is unavailable.").foregroundStyle(LFTheme.warning)
                    } else if value.events.contains(where: { $0.change != 0 }) {
                        columnLayout {
                            figure("Lowest projected balance", value.lowestBalance, currency: value.anchor.currency,
                                   detail: value.firstShortfall.map { "Shortfall on " + $0.date.presentation } ?? "Based on included payments")
                            figure("Protected balance", value.reserveFloor, currency: value.anchor.currency,
                                   detail: "After bills")
                        }
                        RunwayBalanceChart(runway: value).id(value.id)
                    } else {
                        Text("Starting balance carried forward").font(theme.typography.body.weight(.semibold))
                        Text("No future payments are included.")
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                    DisclosureGroup("Balances and payments") {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("The protected balance counts overlapping cash floors once.")
                                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                .padding(.bottom, theme.spacing.small)
                            ForEach(value.points) { point in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text(point.date.presentation)
                                        Spacer()
                                        Text(amount(point.balance, value.anchor.currency)).monospacedDigit()
                                    }
                                    Text(point.title).fixedSize(horizontal: false, vertical: true)
                                    if point.transactionIDs.isEmpty {
                                        Text(point.isForecast ? "Forecast" : "Source balance").foregroundStyle(theme.palette.secondaryText)
                                    } else { Button("Transactions") { onTransactions(point.transactionIDs) }.lfSecondaryAction() }
                                }.padding(.vertical, 8)
                                Divider()
                            }
                        }
                    }.font(theme.typography.secondary)
                    fundingNeeds(projection, target: value)
                }
                LFPanel(contentSpacing: 14) { planActual(projection, currency: value.anchor.currency) }
                LFPanel(contentSpacing: 12) {
                    DisclosureGroup("Assumptions and missing information (\(value.limitations.count + projection.cardNeeds.count))", isExpanded: $showAssumptions) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Dashed path: forecast. Solid points: recorded balance or movements. No undated salary estimate is added to this path.")
                            ForEach(value.limitations + projection.cardNeeds, id: \.self) { Text($0) }
                        }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText).padding(.top, 6)
                    }
                    if !capacity.1.isEmpty {
                        DisclosureGroup("What needs review") {
                            ForEach(capacity.1, id: \.self) { Text($0).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText) }
                            HStack(spacing: 16) {
                                Button("Open Commitments") { selection.section = "Commitments" }.buttonStyle(.link)
                                Button("Open Reserves") { selection.section = "Reserves" }.buttonStyle(.link)
                                Button("Salary assistance") { editor = .preferences }.buttonStyle(.link)
                            }
                        }
                    }
                    scenarioControls(account: value)
                }
            } else {
                LFPanel(title: "Balance forecast") {
                    Text("No eligible account balance is available for this forecast.").foregroundStyle(theme.palette.secondaryText)
                    Button("Review funding and actuals") { editor = .funding }.lfSecondaryAction()
                }
            }
        }
    }

    private func commitments(_ projection: PlanningProjection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming commitments").font(theme.typography.sectionTitle)
                Spacer()
                Button("Add recurring commitment") { editor = .recurring(nil, nil) }.lfSecondaryAction()
                Button("Review monthly amounts") { editor = .prefills(projection.recurring.filter { planner.plan.includesRecurring($0.date) && !planner.excludedPlanningAccountIDs.contains($0.definition.accountID) }) }.lfPrimaryAction()
            }
            if projection.recurring.isEmpty { Text("Add a confirmed recurring commitment, or review a repeated-payment candidate below.").foregroundStyle(theme.palette.secondaryText) }
            let schedules = Dictionary(grouping: projection.recurring, by: { $0.definition.id })
            let firstPayments = schedules.values.compactMap { $0.min { $0.date < $1.date } }.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
            ForEach(firstPayments) { payment in
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(payment.definition.title).font(theme.typography.body.weight(.semibold))
                        Text((accounts.first { $0.id == payment.definition.accountID }?.title ?? "Saved account") + " · Due " + payment.date.presentation)
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(amount(payment.remaining, payment.currency)).monospacedDigit()
                        Text(paymentStatus(payment)).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                    Button(payment.suggestionIDs.isEmpty ? "Review payment" : "Review \(payment.suggestionIDs.count) matches") { editor = .payment(payment) }.lfSecondaryAction()
                    Button("Edit recurring") { editor = .recurring(payment.definition, nil) }.lfSecondaryAction()
                }.padding(.vertical, 9)
                let later = (schedules[payment.definition.id] ?? []).filter { $0.id != payment.id }.sorted { $0.date < $1.date }
                if !later.isEmpty {
                    DisclosureGroup("Later payments (\(later.count))", isExpanded: Binding(
                        get: { expandedCommitmentID == payment.definition.id },
                        set: { expandedCommitmentID = $0 ? payment.definition.id : nil })) {
                        ForEach(later) { occurrence in
                            HStack {
                                Text(occurrence.date.presentation)
                                Text(amount(occurrence.remaining, occurrence.currency)).font(theme.typography.body.weight(.semibold)).monospacedDigit()
                                Text(paymentStatus(occurrence)).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                Spacer()
                                Button("Review payment") { editor = .payment(occurrence) }.lfSecondaryAction()
                            }.padding(.vertical, 6)
                        }
                    }
                }
                Divider()
            }
            let pendingCandidates = projection.candidates.filter { $0.decision == nil }
            let dismissedCandidates = projection.candidates.filter { $0.decision == .dismissed }
            DisclosureGroup("Repeated payments to review (\(pendingCandidates.count))") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Similar descriptions, amounts and monthly dates suggest a recurring payment. Review it before adding a commitment.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    ForEach(pendingCandidates.prefix(25)) { value in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(value.narration).lineLimit(2)
                                Text("\(value.dates.count) recorded months · \(amount(value.amount, value.currency))").font(theme.typography.secondary)
                            }
                            Spacer()
                            Button("Source transactions") { onTransactions(Set(value.transactionIDs)) }.lfSecondaryAction()
                            Button("Review as recurring") { editor = .recurring(nil, value) }.lfSecondaryAction()
                            Button("Dismiss") { setCandidateDecision(value.id, .dismissed) }.lfSecondaryAction()
                        }
                    }
                }.padding(.top, 10)
            }
            if !dismissedCandidates.isEmpty {
                DisclosureGroup("Dismissed patterns (\(dismissedCandidates.count))") {
                    ForEach(dismissedCandidates) { value in
                        HStack {
                            Text(value.narration).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            Text(amount(value.amount, value.currency)).monospacedDigit()
                            Button("Review again") { setCandidateDecision(value.id, nil) }.lfSecondaryAction()
                        }.padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func paymentStatus(_ payment: RecurringPaymentProjection) -> String {
        if payment.isExcludedFromPlan { return payment.status }
        if payment.paid == 0, !payment.isWaived, let today = FinancialCalendar.statement(Date()), payment.date > today {
            return "Upcoming payment"
        }
        return payment.status
    }

    private func reserves(_ projection: PlanningProjection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Reserve currency")
                Picker("Reserve currency", selection: $selection.currency) { ForEach(["QAR", "INR", "USD"], id: \.self) { Text($0) } }
                    .labelsHidden().tint(theme.palette.primaryText).frame(width: 100)
                Spacer()
                Button("Add reserve target") { editor = .reserve(nil) }.lfSecondaryAction()
            }
            let values = projection.reserves.filter { $0.designation.target.currency == currency }
            if values.isEmpty { Text("No reserve targets in this currency. Targets are owner choices; they do not create cash or investment holdings.").foregroundStyle(theme.palette.secondaryText) }
            if !values.isEmpty {
                ReserveProgressChart(values: values, currency: currency)
            }
            ForEach(values) { value in
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(value.designation.title).font(theme.typography.body.weight(.semibold))
                        Text(value.basis).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(value.fundedAfterBills.map { amount($0, currency) } ?? "Funding unknown").monospacedDigit()
                        Text("Target " + amount(value.target, currency)).font(theme.typography.secondary)
                        Text("Planned this month: " + (assistance.contributions.contains { $0.designationID == value.id } ? amount(value.proposedContribution, currency) : "Not selected")).font(theme.typography.secondary)
                    }
                    Button("Edit target") { editor = .reserve(value.designation) }.lfSecondaryAction()
                    Button("Plan contribution") { editor = .contribution(value.designation) }.lfSecondaryAction()
                }.padding(.vertical, 9)
                Divider()
            }
            Text("Reserve targets are balances to protect after bills. Monthly contributions are separate choices. Additional saving builds these reserves before outside-ISP investing; existing payroll ISP contributions are not deducted from received net pay again.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func scenarioControls(account: AccountRunway) -> some View {
        DisclosureGroup("What if…") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Unsaved scenario for \(account.anchor.title) in \(account.anchor.currency)").font(theme.typography.secondary)
                HStack {
                    TextField("Extra net income", text: $selection.scenarioIncome)
                    TextField("One-off cost", text: $selection.scenarioCost)
                    TextField("Additional reserve contribution", text: $selection.scenarioContribution)
                    Stepper("Payment delay: \(scenario.paymentDelayDays) days", value: $selection.scenario.paymentDelayDays, in: 0...30).fixedSize()
                }.textFieldStyle(.roundedBorder)
                HStack {
                    Button("Compare scenario") {
                        guard let income = decimal(selection.scenarioIncome), let cost = decimal(selection.scenarioCost), let contribution = decimal(selection.scenarioContribution), income >= 0, cost >= 0, contribution >= 0 else { message = "Enter amounts of zero or more with up to two decimals."; return }
                        scenario.accountID = account.id; scenario.extraIncome = income; scenario.extraCost = cost; scenario.contributionChange = contribution
                    }.lfSecondaryAction()
                    Button("Reset scenario") { scenario = .init(); selection.scenarioIncome = ""; selection.scenarioCost = ""; selection.scenarioContribution = "" }.lfSecondaryAction()
                    if scenario.isActive { Text("Scenario · does not change the saved plan").foregroundStyle(theme.palette.secondaryText) }
                }
            }.padding(.top, 8)
        }
    }

    private func planActual(_ projection: PlanningProjection, currency: String) -> some View {
        let payments = projection.recurring.filter { planner.plan.includesRecurring($0.date) && $0.currency == currency && !$0.isExcludedFromPlan }
        let actual = payments.reduce(Decimal.zero) { $0 + $1.paid }, remaining = payments.reduce(Decimal.zero) { $0 + $1.remaining }
        let activityIDs = projection.actualTransactionIDs[currency, default: []]
        let observedRows = model.rows.filter { row in row.currency == currency && row.date.map { planner.plan.includesRecurring($0) } == true }
        let observedAccounts = Set(observedRows.map(\.accountID))
        let covered = !observedAccounts.isEmpty && observedAccounts.allSatisfy {
            store.sources.hasCompleteCoverage(accountID: $0, start: planner.plan.recurringStart, end: planner.plan.recurringEnd)
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Plan & recorded activity · \(currency)").font(theme.typography.sectionTitle)
            Text("Recorded-activity period: " + planner.plan.recurringStart.presentation + "–" + planner.plan.recurringEnd.presentation)
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            columnLayout {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Recurring commitments").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    if payments.isEmpty {
                        let configured = metadata?.recurring.contains { $0.revisions.contains { $0.amount.currency == currency } } == true
                        Text(configured ? "No recurring payments included in this period" : "Not configured").font(theme.typography.sectionTitle)
                        Text("Matched and remaining amounts are unavailable.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        Button("Open Commitments") { selection.section = "Commitments" }.buttonStyle(.link)
                    } else {
                        Text(actual == 0 ? "No matched payments" : "Matched: " + amount(actual, currency)).font(theme.typography.body.weight(.semibold))
                        Text("Remaining: " + amount(remaining, currency)).monospacedDigit()
                        Text(payments.contains { !$0.hasCoverage } ? "Statements do not cover the full payment periods." : "Statements cover the payment periods.")
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        Chart {
                            BarMark(x: .value("Value", numeric(actual)), y: .value("Measure", "Matched payments")).foregroundStyle(theme.palette.accent)
                            BarMark(x: .value("Value", numeric(remaining)), y: .value("Measure", "Remaining")).foregroundStyle(theme.palette.secondaryText)
                        }.frame(height: 85).accessibilityLabel("Matched and remaining recurring cash commitments")
                    }
                    Button("Matched transactions") { onTransactions(Set(payments.flatMap(\.actualIDs))) }
                        .lfSecondaryAction().disabled(payments.allSatisfy { $0.actualIDs.isEmpty })
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 9) {
                    Text("Recorded consumption").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    Text(observedRows.isEmpty ? "No recorded activity" : amount(projection.actualSpending[currency, default: 0], currency))
                        .font(theme.typography.sectionTitle).monospacedDigit()
                    Text(observedRows.isEmpty ? "No transactions recorded in this currency and period; spending is unknown." : "\(observedRows.count) recorded transactions · \(covered ? "statements cover these accounts for this period" : "statements do not cover the full period")")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    Button("Spending transactions") { onTransactions(activityIDs) }.lfSecondaryAction().disabled(activityIDs.isEmpty)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup("Consumption scope and allowance") {
            Text("Consumption includes recognized purchases and refunds. Loan and EMI entries are excluded; card payments remain cash commitments. \(projection.unmatchedSpendingCount) transactions in this period still need interpretation.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if let allowance = assistance.allowance, allowance.currency == currency,
                       assistance.allowanceAccountID.map(planner.excludedHistoryAccountIDs.contains) != true {
                let committedIDs = Set(payments.flatMap(\.actualIDs))
                let spendingIDs = projection.actualTransactionIDs[currency, default: []].subtracting(committedIDs)
                let discretionary = model.rows.filter { spendingIDs.contains($0.id) && $0.accountID == assistance.allowanceAccountID }.reduce(Decimal.zero) { total, row in
                    total + SpendingIntelligence.interpretation(row, confirmed: metadata?.confirmedByTransaction[row.id]).spending
                }
                let limit = (try? allowance.money().amount) ?? 0
                Text("Discretionary allowance: " + allowance.decimal + " " + currency + " · remaining " + amount(limit - discretionary, currency)).font(theme.typography.body.weight(.semibold))
                Chart {
                    BarMark(x: .value("Amount", numeric(discretionary)), y: .value("Measure", "Recorded discretionary spending")).foregroundStyle(Color.cyan)
                    BarMark(x: .value("Amount", numeric(limit - discretionary)), y: .value("Measure", "Remaining allowance")).foregroundStyle(limit - discretionary < 0 ? LFTheme.warning : theme.palette.secondaryText)
                }.frame(height: 100).accessibilityLabel("Discretionary spending and signed remaining allowance")
                Button("Discretionary transactions") { onTransactions(Set(model.rows.filter { spendingIDs.contains($0.id) && $0.accountID == assistance.allowanceAccountID }.map(\.id))) }.lfSecondaryAction()
            } else { Button("Choose discretionary allowance") { editor = .budget }.lfSecondaryAction() }
            }
        }
    }
    private func fundingNeeds(_ projection: PlanningProjection, target: AccountRunway) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let shortage = target.firstShortfall, let lowest = target.lowestBalance, lowest < 0 {
                Text("Funding needed by \(shortage.date.presentation): at least \(amount(-lowest, target.anchor.currency)) over this forecast.")
                    .font(theme.typography.body.weight(.semibold)).foregroundStyle(LFTheme.warning)
                Text("Possible routes below are alternatives using the same cash. Their dated balances and coverage still need review.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                if let to = accounts.first(where: { $0.id == target.id }) {
                    ForEach(projection.runways.filter { source in
                        accounts.first(where: { $0.id == source.id }).map { PlanningIntelligence.permitsPlanningRoute(from: $0, to: to, retentionAccountID: metadata?.preferences?.retentionAccountID) } ?? false
                    }) { source in
                        let principal = (try? Money(amount: -lowest, currency: target.anchor.currency)).flatMap { PlanningIntelligence.transferPrincipal(received: $0, fromCurrency: source.anchor.currency, plan: planner.plan) }
                        Text(source.anchor.title + ": required principal " + (principal.map { MoneyFormatting.display($0) } ?? "Conversion unavailable") + "; conditional headroom after bills and reserve " + (source.conditionalHeadroom.map { amount($0, source.anchor.currency) } ?? "unavailable"))
                            .font(theme.typography.secondary)
                    }
                }
                Button("Choose funding in this plan") { editor = .funding }.lfSecondaryAction()
            }
        }
    }
    private func figure(_ title: String, _ value: Decimal?, currency: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text(value.map { amount($0, currency) } ?? "Unavailable").font(theme.typography.sectionTitle).monospacedDigit()
            Text(detail).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func refresh() {
        model.refresh(plan: planner.plan, scenario: scenario, selectedHistoryAccountIDs: planner.selectedHistoryAccountIDs,
            retainedRecurringOccurrenceIDs: planner.retainedRecurringOccurrenceIDs,
            excludedRecurringOccurrenceIDs: planner.recurringOccurrenceExclusions)
    }
    private func setCandidateDecision(_ key: String, _ decision: RecurringCandidateDecision?) {
        let previous = metadata?.preferences
        var value = previous ?? .init(workspaceID: planner.plan.workspaceID)
        var decisions = value.recurringCandidateDecisions ?? [:]
        decisions[key] = decision
        value.recurringCandidateDecisions = decisions
        mutate { try FinancialIntelligenceCoordinator().applyPlanning(.preferences(value, replacing: previous), generation: planner.generation) }
    }
    private func amount(_ value: Decimal, _ currency: String) -> String { (try? Money(amount: value, currency: currency)).map { MoneyFormatting.display($0) } ?? "Unavailable" }
    private func numeric(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private func decimal(_ text: String) -> Decimal? { text.isEmpty ? 0 : (try? PlannerInputCodec.money(text, currency: selectedRunway?.anchor.currency ?? "QAR", locale: .current).amount) }
    private func mutate(_ body: @escaping () throws -> Void) {
        do { try body(); editor = nil; message = nil }
        catch {
#if DEBUG
            if case DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) = error { pending = { mutate(body) }; challenge = value; return }
#endif
            message = error.localizedDescription
        }
    }
}
