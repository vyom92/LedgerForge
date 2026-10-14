import SwiftUI
import Charts

/// Device-local observation state; never inferred from Mac publication time.
struct CompanionReadStatus: Equatable {
    var message: String
    var lastCheckedAt: Date?
    var isChecking: Bool
}

private enum CompanionTab: Hashable { case dashboard, investments, monthlyPlan }
private enum CompanionInvestmentRoute: Hashable {
    case allHoldings, group(String), fund(group: String, fund: String), container(String), holding(String)
}

/// iOS 17+ SwiftUI APIs; configure the actual deployment target in the primary.
/// MonthlyPlan is content only: this shell owns its NavigationStack.
struct CompanionPhoneShell<MonthlyPlan: View>: View {
    let snapshot: CompanionReadSnapshot?
    let status: CompanionReadStatus
    let monthlyPlanTitle: String
    let monthlyPlanSummary: [CompanionReadMetric]
    let monthlyPlanMessage: String?
    private let connectionToolbar: CompanionConnectionToolbar
    private let monthlyPlan: MonthlyPlan
    @State private var selection = CompanionTab.dashboard

    init(snapshot: CompanionReadSnapshot?, status: CompanionReadStatus,
         checkDisabled: Bool, onConnection: @escaping () -> Void, onCheck: @escaping () -> Void,
         monthlyPlanTitle: String = "Monthly Plan", monthlyPlanSummary: [CompanionReadMetric] = [],
         monthlyPlanMessage: String? = nil, @ViewBuilder monthlyPlan: () -> MonthlyPlan) {
        self.snapshot = snapshot; self.status = status
        self.connectionToolbar = CompanionConnectionToolbar(isChecking: status.isChecking,
            checkDisabled: checkDisabled, onConnection: onConnection, onCheck: onCheck)
        self.monthlyPlanTitle = monthlyPlanTitle; self.monthlyPlanSummary = monthlyPlanSummary
        self.monthlyPlanMessage = monthlyPlanMessage; self.monthlyPlan = monthlyPlan()
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                CompanionPhoneDashboard(snapshot: snapshot, status: status, connectionToolbar: connectionToolbar,
                    monthlyPlanTitle: monthlyPlanTitle, monthlyPlanSummary: monthlyPlanSummary,
                    monthlyPlanMessage: monthlyPlanMessage,
                    openInvestments: { selection = .investments }, openPlan: { selection = .monthlyPlan })
            }
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }.tag(CompanionTab.dashboard)
            CompanionPhoneInvestments(snapshot: snapshot, status: status, connectionToolbar: connectionToolbar)
                .tabItem { Label("Investments", systemImage: "chart.pie.fill") }.tag(CompanionTab.investments)
            NavigationStack {
                monthlyPlan.navigationTitle("Monthly Plan").toolbar { connectionToolbar }
            }
                .tabItem { Label("Monthly Plan", systemImage: "calendar") }.tag(CompanionTab.monthlyPlan)
        }
    }
}

/// Shared native items leave the title and leading back control to NavigationStack.
private struct CompanionConnectionToolbar: ToolbarContent {
    let isChecking: Bool
    let checkDisabled: Bool
    let onConnection: () -> Void
    let onCheck: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: onConnection) {
                Label("Connection", systemImage: "externaldrive")
            }.labelStyle(.iconOnly)
            Button(action: onCheck) {
                if isChecking { ProgressView().accessibilityLabel("Checking") }
                else { Label("Check", systemImage: "arrow.clockwise") }
            }
            .labelStyle(.iconOnly)
            .disabled(checkDisabled)
        }
    }
}

private struct CompanionPhoneDashboard: View {
    let snapshot: CompanionReadSnapshot?
    let status: CompanionReadStatus
    let connectionToolbar: CompanionConnectionToolbar
    let monthlyPlanTitle: String
    let monthlyPlanSummary: [CompanionReadMetric]
    let monthlyPlanMessage: String?
    let openInvestments: () -> Void
    let openPlan: () -> Void

    var body: some View {
        List {
            CompanionFreshnessSection(snapshot: snapshot, status: status)
            if let dashboard = snapshot?.dashboard {
                Section("Net worth estimate") {
                    if let message = dashboard.message { Text(message).foregroundStyle(.secondary) }
                    if dashboard.state == .ready { CompanionMetricRows(metrics: dashboard.totals) }
                }
                if dashboard.state == .ready {
                    ForEach(dashboard.charts) { chart in
                        Section(chart.title + " · " + chart.currency) {
                            CompanionChart(chart: chart)
                        }
                    }
                    Section("Report breakdown") {
                        ForEach(dashboard.members) { member in
                            NavigationLink {
                                List {
                                    Section { Text(member.context); Text(member.isIncluded.map { $0 ? "Included in net worth" : "Excluded from net worth" } ?? "Reporting membership unavailable") }
                                    CompanionMetricRows(metrics: member.metrics)
                                    CompanionFactRows(facts: member.details)
                                }.navigationTitle(member.title).navigationBarTitleDisplayMode(.inline)
                                    .toolbar { connectionToolbar }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(member.title)
                                    Text(member.kind + (member.isIncluded == false ? " · Excluded from net worth" : ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
                Section {
                    Button("Open Investments", systemImage: "chart.pie") { openInvestments() }
                }
                Section(monthlyPlanTitle) {
                    CompanionMetricRows(metrics: monthlyPlanSummary)
                    if let monthlyPlanMessage { Text(monthlyPlanMessage).foregroundStyle(.secondary) }
                    Button("Open Monthly Plan", systemImage: "calendar") { openPlan() }
                }
                ForEach(dashboard.positions) { group in
                    Section(group.title) {
                        CompanionMetricRows(metrics: [group.total])
                        ForEach(group.accounts) { account in
                            DisclosureGroup {
                                CompanionFactRows(facts: account.details)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(account.title)
                                    Text(account.metrics.first?.display ?? "Unavailable").monospacedDigit()
                                    Text(account.context).font(.caption).foregroundStyle(.secondary)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
                Section("Report context") {
                    ForEach(Array(dashboard.scopeNotes.enumerated()), id: \.offset) { _, note in Text(note) }
                    Text("History-only accounts: \(dashboard.historyOnlyCount)")
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView("No Mac snapshot yet", systemImage: "desktopcomputer",
                    description: Text("Choose the companion folder and receive a complete snapshot from your Mac."))
            }
        }.navigationTitle("Dashboard")
            .toolbar { connectionToolbar }
    }
}

private struct CompanionPhoneInvestments: View {
    let snapshot: CompanionReadSnapshot?
    let status: CompanionReadStatus
    let connectionToolbar: CompanionConnectionToolbar
    @State private var path: [CompanionInvestmentRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                CompanionFreshnessSection(snapshot: snapshot, status: status)
                if let investments = snapshot?.investments {
                    if investments.state == .ready {
                        Section("Investments") { CompanionMetricRows(metrics: investments.metrics) }
                        Section("Portfolios") {
                            ForEach(investments.groups) { group in
                                NavigationLink(value: CompanionInvestmentRoute.group(group.id)) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(group.title)
                                        Text("\(group.holdingIDs.count) holdings").font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 4)
                                }
                            }
                            NavigationLink("All holdings", value: CompanionInvestmentRoute.allHoldings)
                        }
                        Section("Containers") {
                            ForEach(investments.containers) { container in
                                NavigationLink(value: CompanionInvestmentRoute.container(container.id)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(container.title)
                                        Text(container.institution).font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                        Section("Valuation basis") {
                            Text(investments.basis)
                            CompanionFactRows(facts: investments.sourceDetails)
                        }
                    } else {
                        Text(investments.message ?? (investments.state == .empty ? "No current holdings" : "Current holdings unavailable"))
                        // Container inventory can legitimately exist without any holding.
                        ForEach(investments.containers) { container in
                            NavigationLink(container.title, value: CompanionInvestmentRoute.container(container.id))
                        }
                    }
                } else {
                    ContentUnavailableView("No investment snapshot yet", systemImage: "chart.pie",
                        description: Text("Investments appear after a complete Mac snapshot is received."))
                }
            }
            .navigationTitle("Investments")
            .toolbar { connectionToolbar }
            .navigationDestination(for: CompanionInvestmentRoute.self) { route in
                destination(route).toolbar { connectionToolbar }
            }
        }
        .onChange(of: snapshot?.ledgerLineage) { _, _ in path = [] }
    }

    @ViewBuilder private func destination(_ route: CompanionInvestmentRoute) -> some View {
        if let data = snapshot?.investments {
            switch route {
            case .allHoldings:
                List { holdingLinks(data.holdings) }.navigationTitle("All holdings")
            case .group(let id):
                if let group = data.groups.first(where: { $0.id == id }) {
                    List {
                        Section { CompanionMetricRows(metrics: group.metrics) }
                        Section("Funds") {
                            ForEach(group.funds) { fund in
                                NavigationLink(fund.title, value: CompanionInvestmentRoute.fund(group: id, fund: fund.id))
                            }
                        }
                        Section("All group holdings") { holdingLinks(data.holdings.filter { group.holdingIDs.contains($0.id) }) }
                        Section("Coverage") { ForEach(Array(group.notes.enumerated()), id: \.offset) { _, note in Text(note) } }
                    }.navigationTitle(group.title).navigationBarTitleDisplayMode(.inline)
                } else { removedItem }
            case .fund(let groupID, let fundID):
                if let fund = data.groups.first(where: { $0.id == groupID })?.funds.first(where: { $0.id == fundID }) {
                    List {
                        Section { Text(fund.identifier); CompanionMetricRows(metrics: fund.metrics) }
                        Section("Positions") { holdingLinks(data.holdings.filter { fund.holdingIDs.contains($0.id) }) }
                        Section("Source dates") { CompanionFactRows(facts: fund.details) }
                    }.navigationTitle(fund.title).navigationBarTitleDisplayMode(.inline)
                } else { removedItem }
            case .container(let id):
                if let container = data.containers.first(where: { $0.id == id }) {
                    List {
                        Section {
                            Text(container.institution)
                            LabeledContent(container.identityLabel, value: container.identity)
                            Text(container.includedInNetWorth.map { $0 ? "Included in net worth" : "Excluded from net worth" } ?? "Reporting membership unavailable")
                        }
                        Section("Policy values") { CompanionMetricRows(metrics: container.metrics) }
                        Section("Holdings") { holdingLinks(data.holdings.filter { $0.containerID == id }) }
                        Section("Source context") { CompanionFactRows(facts: container.details) }
                    }.navigationTitle(container.title).navigationBarTitleDisplayMode(.inline)
                } else { removedItem }
            case .holding(let id):
                if let holding = data.holdings.first(where: { $0.id == id }) {
                    List {
                        Section {
                            Text(holding.currency)
                            if let container = data.containers.first(where: { $0.id == holding.containerID }) { Text(container.title) }
                            LabeledContent("Units", value: holding.unitsDisplay)
                            if let issue = holding.issue { Label(issue, systemImage: "exclamationmark.circle") }
                        }
                        Section("Value and cost") { CompanionMetricRows(metrics: holding.metrics) }
                        Section("Source and exact details") { CompanionFactRows(facts: holding.details) }
                    }.navigationTitle(holding.title).navigationBarTitleDisplayMode(.inline)
                } else { removedItem }
            }
        } else { removedItem }
    }

    private func holdingLinks(_ holdings: [CompanionInvestmentHolding]) -> some View {
        ForEach(holdings) { holding in
            NavigationLink(value: CompanionInvestmentRoute.holding(holding.id)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(holding.title)
                    Text(holding.metrics.first(where: { $0.id == "value" })?.display ?? "Unavailable").monospacedDigit()
                    Text(holding.unitsDisplay + " units · " + holding.currency).font(.caption).foregroundStyle(.secondary)
                    if let issue = holding.issue { Text(issue).font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 4)
            }
        }
    }
    private var removedItem: some View {
        ContentUnavailableView("Item no longer in this snapshot", systemImage: "arrow.triangle.2.circlepath",
            description: Text("Return to Investments to view the current inventory."))
    }
}

private struct CompanionChart: View {
    let chart: CompanionReadChart
    @ScaledMetric(relativeTo: .body) private var chartRowHeight: CGFloat = 45
    @ScaledMetric(relativeTo: .body) private var minimumChartHeight: CGFloat = 120
    var body: some View {
        Chart(chart.rows) { row in
            if let value = row.coordinate {
                BarMark(x: .value(chart.currency, value), y: .value("Position", row.title))
                    .foregroundStyle(value < 0 ? Color.orange : Color.accentColor)
                    .accessibilityLabel(row.title)
                    .accessibilityValue(row.metrics.first { $0.id == chart.currency }?.display ?? "Unavailable")
            }
        }
        .frame(height: max(minimumChartHeight, CGFloat(chart.rows.count) * chartRowHeight))
        Text(chart.note).font(.caption).foregroundStyle(.secondary)
        ForEach(chart.rows) { row in
            DisclosureGroup(row.title) {
                CompanionMetricRows(metrics: row.metrics)
                CompanionFactRows(facts: row.details)
            }
        }
    }
}

private struct CompanionMetricRows: View {
    let metrics: [CompanionReadMetric]
    var body: some View {
        ForEach(metrics) { metric in
            VStack(alignment: .leading, spacing: 5) {
                Text(metric.label).font(.subheadline).foregroundStyle(.secondary)
                Text(metric.display).font(.headline).monospacedDigit().textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = metric.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                if let exact = metric.exact {
                    DisclosureGroup("Exact value") {
                        Text((exact.denominator == "1" ? exact.numerator : exact.numerator + " / " + exact.denominator) + " " + exact.currency)
                            .font(.caption).monospacedDigit().textSelection(.enabled)
                    }
                }
            }.padding(.vertical, 4).accessibilityElement(children: .combine)
        }
    }
}

private struct CompanionFactRows: View {
    let facts: [CompanionReadFact]
    var body: some View {
        ForEach(facts) { fact in
            VStack(alignment: .leading, spacing: 4) {
                Text(fact.label).font(.subheadline).foregroundStyle(.secondary)
                Text(fact.value).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 4).accessibilityElement(children: .combine)
        }
    }
}

private struct CompanionFreshnessSection: View {
    let snapshot: CompanionReadSnapshot?
    let status: CompanionReadStatus
    var body: some View {
        Section {
            if status.isChecking { ProgressView("Checking companion folder…") }
            if !status.message.isEmpty { Text(status.message).font(.subheadline) }
            if let date = snapshot?.publishedAt {
                LabeledContent("Mac snapshot", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            if let date = status.lastCheckedAt {
                LabeledContent("Last checked on iPhone", value: date.formatted(date: .abbreviated, time: .shortened))
            }
        }.font(.caption)
    }
}
