import SwiftUI
import Charts

/// A report over the already-published projection. Display choices are local;
/// inclusion changes use the existing metadata transaction/hydration lane.
struct DashboardNetWorthCard: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject private var preferences = ReportingCurrencyPreferences.shared
    let report: NetWorthReport
    let workspaceID: String
    let permitsMutation: Bool
    private enum ExpandedSection: Equatable {
        case chart(String)
        case breakdown(NetWorthMember.Kind?, NetWorthMemberID?)
    }
    @State private var expandedSection: ExpandedSection?
    @State private var showsDetails = false
    @Binding var showsZeroBalances: Bool
    @State private var failure: String?
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pendingChoice: (Bool, NetWorthMemberID, ProviderGenerationToken)?
#endif

    var body: some View {
        LFPanel(title: "Net worth estimate", trailing: AnyView(currencyMenu), contentSpacing: theme.spacing.controlGap) {
            switch report.state {
            case .loading:
                ProgressView("Loading recorded positions…")
            case .unavailable:
                supporting("Current financial data is unavailable. Reopen or resolve the database status in Settings.")
            case .membershipUnavailable:
                supporting("Saved report choices are unavailable. The estimate will return after a successful database reload.")
            case .noData:
                supporting("No current bank, card or investment positions are recorded.")
            case .noIncludedMembers:
                supporting("No accounts included. Include an account or investment container in the breakdown below.")
            case .ready:
                totals
                reportStatus
                NetWorthChartsView(report: report, selectedRow: chartSelection)
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !report.members.isEmpty {
                DisclosureGroup("Breakdown", isExpanded: Binding(
                    get: { if case .breakdown = expandedSection { return true }; return false },
                    set: { expandedSection = $0 ? .breakdown(nil, nil) : nil; showsDetails = false })) {
                    breakdown.padding(.top, theme.spacing.small)
                }
                .font(theme.typography.secondary)
            }
        }
#if DEBUG
        .alert(DevelopmentProfileAcknowledgementPresentation.title,
               isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pendingChoice = nil } })) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) { approveChoice() }
            Button("Cancel", role: .cancel) { challenge = nil; pendingChoice = nil }
        } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }

    private var currencyMenu: some View {
        Menu("Currencies") {
            ForEach(ReportingCurrency.allCases) { currency in
                Toggle(currency.rawValue, isOn: Binding(
                    get: { preferences.currencies.contains(currency) },
                    set: { preferences.setVisible($0, currency: currency) }))
                    .disabled(preferences.currencies == [currency])
            }
        }
        .lfMenuAction()
        .accessibilityIdentifier("netWorth.currencies")
        .help("Choose the currencies shown in this report. At least one stays visible.")
    }

    private var chartSelection: Binding<String?> {
        Binding(get: {
            if case .chart(let id) = expandedSection { return id }
            return nil
        }, set: { value in
            expandedSection = value.map(ExpandedSection.chart)
            showsDetails = false
        })
    }

    private var totals: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                ForEach(report.targets) { target in total(target) }
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                ForEach(report.targets) { target in total(target) }
            }
        }
    }

    private func total(_ target: NetWorthTarget) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(target.currency.rawValue)
                .font(theme.typography.body.weight(.medium))
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: true, vertical: false)
            Text(target.amount?.display ?? "Unavailable")
                .font(theme.typography.headlineMoney)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Net worth \(target.currency.rawValue): \(target.amount?.display ?? "unavailable"). \(target.label)")
            if Set(report.targets.map(\.label)).count > 1 {
                supporting(target.label + (target.missingCount == 0 ? "" : " · \(target.missingCount) unavailable"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reportStatus: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                if Set(report.targets.map(\.label)).count == 1, let target = report.targets.first {
                    supporting(target.label + missingSummary)
                }
                supporting("Recorded positions only · Source dates vary")
            }
            Spacer(minLength: theme.spacing.small)
            Button("Details", systemImage: "info.circle") { expandedSection = nil; showsDetails.toggle() }
                .buttonStyle(.borderless)
                .font(theme.typography.secondary)
                .accessibilityIdentifier("netWorth.details")
                .popover(isPresented: $showsDetails) { reportDetails }
        }
    }

    private var missingSummary: String {
        let counts = Set(report.targets.map(\.missingCount))
        if counts.count == 1, let count = counts.first, count > 0 {
            return " · \(count) \(count == 1 ? "position unavailable" : "positions unavailable")"
        }
        let details = report.targets.filter { $0.missingCount > 0 }.map { "\($0.currency.rawValue): \($0.missingCount) unavailable" }
        return details.isEmpty ? "" : " · " + details.joined(separator: ", ")
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            ForEach(NetWorthMember.Kind.allCases, id: \.self) { kind in
                let members = report.members.filter { $0.kind == kind }
                let hidden = members.filter(\.isIncludedZeroBalanceAccount)
                if !members.isEmpty {
                    DisclosureGroup(isExpanded: Binding(
                        get: { if case .breakdown(let selected, _) = expandedSection { return selected == kind }; return false },
                        set: { expandedSection = .breakdown($0 ? kind : nil, nil) })) {
                        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                            ForEach(members.filter { showsZeroBalances || !$0.isIncludedZeroBalanceAccount }) { member in memberRow(member) }
                            if !hidden.isEmpty {
                                Toggle("Show \(hidden.count) zero-balance \(hidden.count == 1 ? "account" : "accounts")", isOn: $showsZeroBalances)
                                    .toggleStyle(.checkbox)
                                    .font(theme.typography.caption)
                                    .accessibilityIdentifier("netWorth.showZeroBalances." + kind.rawValue)
                            }
                        }
                        .padding(.vertical, theme.spacing.small)
                    } label: {
                        HStack(spacing: theme.spacing.controlGap) {
                            Text(kind.rawValue).font(theme.typography.rowTitle)
                            Spacer(minLength: theme.spacing.small)
                            let excluded = members.filter { !$0.isIncluded }.count
                            supporting("\(members.count) \(kind == .investment ? "containers" : "accounts")"
                                + (excluded == 0 ? "" : " · \(excluded) excluded"))
                        }
                    }
                    Divider()
                }
            }
        }
    }

    private var reportDetails: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Text("About this estimate").font(theme.typography.rowTitle)
                ForEach(report.targets) { target in
                    supporting(target.currency.rawValue + ": " + target.label
                        + (target.missingCount == 0 ? "" : " · \(target.missingCount) positions unavailable"))
                }
                supporting("Balances and holdings have different source dates. Transfers may span those dates.")
                ForEach(report.scopeNotes, id: \.self) { supporting($0) }
            if report.historyOnlyCount > 0 {
                supporting("\(report.historyOnlyCount) closed, settled history-only \(report.historyOnlyCount == 1 ? "account is" : "accounts are") outside current reporting.")
            }
            ForEach(report.targets) { target in
                let dates = target.contributions.flatMap(\.fxDates)
                if let oldest = dates.min(), let newest = dates.max() {
                    supporting("\(target.currency.rawValue) conversion · Al Dar references fetched \(InvestmentPriceDates.fetchInstant(oldest))"
                        + (oldest == newest ? "." : "–\(InvestmentPriceDates.fetchInstant(newest))."))
                }
            }
            supporting("Investment values use current holdings and qualified prices. Policy totals, vested values, cost, salary and planned savings are not added.")
            supporting("Inclusion choices are saved with this ledger and its backups. Display currencies are remembered on this Mac.")
            }
            .padding(theme.spacing.panelPadding)
        }
        .frame(width: 420, height: 360)
    }

    private func memberRow(_ member: NetWorthMember) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                Toggle(isOn: Binding(get: { member.isIncluded }, set: { choose($0, member: member.id) })) {
                    Text(displayTitle(member)).fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
                .font(theme.typography.body)
                .disabled(!permitsMutation || report.generation == nil)
                .accessibilityLabel("Include \(member.title) · \(member.context) in net worth")
                .accessibilityIdentifier("netWorth.include." + member.id.stableKey)
                .help("Include this \(member.kind == .investment ? "whole investment container" : "account") in net worth. The choice saves with the ledger.")
                Spacer(minLength: theme.spacing.small)
                if member.kind != .investment, let component = member.components.first {
                    Text(InvestmentArithmetic.displayedMoney(component.nativeValue, currency: component.currency))
                        .font(theme.typography.tableMoney).monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    let missing = member.components.filter { $0.nativeValue == nil }.count
                    supporting("\(member.components.count) \(member.components.count == 1 ? "holding" : "holdings")"
                        + (missing == 0 ? "" : " · \(missing) unavailable"))
                }
            }
            if member.kind != .investment, let component = member.components.first {
                supporting((member.isIncluded ? "" : "Excluded · ") + component.dateContext)
                    .padding(.leading, theme.spacing.controlGap)
                let issues = componentIssues(component)
                if !issues.isEmpty { supporting(issues.joined(separator: " · ")).padding(.leading, theme.spacing.controlGap) }
            } else {
                if !member.isIncluded { supporting("Excluded from this estimate").padding(.leading, theme.spacing.controlGap) }
                if let issue = member.coverageIssue { supporting(issue).padding(.leading, theme.spacing.controlGap) }
                DisclosureGroup("Holdings and source details", isExpanded: Binding(
                    get: { if case .breakdown(_, let selected) = expandedSection { return selected == member.id }; return false },
                    set: { expandedSection = .breakdown(member.kind, $0 ? member.id : nil) })) {
                    investmentDetails(member).padding(.top, theme.spacing.small)
                }
                .font(theme.typography.caption)
                .padding(.leading, theme.spacing.controlGap)
            }
        }
        .padding(.vertical, theme.spacing.micro)
    }

    private func investmentDetails(_ member: NetWorthMember) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            supporting(member.context)
            if member.components.isEmpty {
                supporting(member.coverageIssue == nil ? "No holdings in this complete dated snapshot." : "No resolved holdings available.")
            }
            ForEach(member.components) { component in
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                        Text(component.title).font(theme.typography.secondary).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: theme.spacing.small)
                        Text(InvestmentArithmetic.displayedMoney(component.nativeValue, currency: component.currency))
                            .font(theme.typography.tableMoney).monospacedDigit()
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    supporting(component.dateContext)
                    if let quote = component.quote {
                        supporting("Price valuation \(AppDateDisplay.civil(quote.valuationDay)) · \(quote.dateBasis.label). Fetched \(InvestmentPriceDates.fetchInstant(quote.fetchedAt)).")
                    }
                    let issues = componentIssues(component)
                    if !issues.isEmpty { supporting(issues.joined(separator: " · ")) }
                }
            }
        }
    }

    private func displayTitle(_ member: NetWorthMember) -> String {
        // Shorten an account-number display label without inferring its type,
        // alias or ownership. The exact saved title remains the accessibility label.
        let identifierCharacters = CharacterSet(charactersIn: "0123456789xX* -")
        if member.kind != .investment, member.title.count >= 8,
           member.title.unicodeScalars.allSatisfy({ identifierCharacters.contains($0) }),
           let institution = member.context.components(separatedBy: " · ").first {
            return institution + " · …" + member.title.suffix(4)
        }
        if let identity = member.identifierLabel, !identity.isEmpty, !member.title.hasSuffix(identity.suffix(4)) {
            return member.title + " · …" + identity.suffix(4)
        }
        return member.title
    }

    private func componentIssues(_ component: NetWorthComponent) -> [String] {
        Array(Set(report.targets.flatMap(\.contributions).filter { $0.id == component.id }.flatMap(\.issues)
            + (component.issue.map { [$0] } ?? []))).sorted()
    }

    private func supporting(_ text: String) -> some View {
        Text(text).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func choose(_ included: Bool, member: NetWorthMemberID) {
        guard permitsMutation, let generation = report.generation else { return }
        save(included, member: member, generation: generation)
    }

    private func save(_ included: Bool, member: NetWorthMemberID, generation: ProviderGenerationToken) {
        failure = nil
        do {
            try NetWorthMembershipCoordinator().setIncluded(included, member: member,
                workspaceID: workspaceID, expectedGeneration: generation)
        } catch {
#if DEBUG
            if case DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) = error {
                challenge = value; pendingChoice = (included, member, generation); return
            }
#endif
            if case AccountMetadataCoordinatorError.savedButRefreshFailed = error {
                failure = "Your choice was saved, but the report could not reload. Reopen the ledger to show the saved result."
            } else {
                failure = "Your choice could not be saved. The previous saved choice is unchanged. Check the database status and try again."
            }
        }
    }
#if DEBUG
    private func approveChoice() {
        guard let challenge, let pendingChoice else { return }
        self.challenge = nil; self.pendingChoice = nil
        switch DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) {
        case .granted, .noAcknowledgementRequired:
            save(pendingChoice.0, member: pendingChoice.1, generation: pendingChoice.2)
        case .staleGeneration, .developmentDatabaseUnavailable:
            failure = "The active ledger changed. Review the current report and choose again."
        }
    }
#endif
}

/// Current-position charts read only the published report. Exact amounts and
/// component IDs stay in the projection; Doubles are used only for chart geometry.
private struct NetWorthChartsView: View {
    @Environment(\.lfTheme) private var theme
    let report: NetWorthReport
    @Binding var selectedRow: String?
    @State private var selectedAngle: Double?
    @State private var isHoveringAllocation = false
    @State private var position: NetWorthChartProjection?
    @State private var allocation: NetWorthChartProjection?
    @State private var convertedValues: [String: [NetWorthChartProjection.ConvertedValue]] = [:]

    private var currency: ReportingCurrency {
        report.targets.first?.currency ?? .usd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            Divider()
            if let position, let allocation {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: theme.spacing.majorModuleGap) {
                        financialPosition(position).frame(minWidth: 360, maxWidth: .infinity)
                        allocationChart(allocation).frame(minWidth: 480, maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                        financialPosition(position)
                        Divider()
                        allocationChart(allocation)
                    }
                }
                if position.isStale || allocation.isStale {
                    Label("Some prices or exchange rates are out of date. See source dates in the details.", systemImage: "clock")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
        .padding(.vertical, theme.spacing.small)
        .onChange(of: report, initial: true) { _, _ in refresh() }
        .onChange(of: selectedRow) { _, _ in selectedAngle = nil }
        .onDisappear { selectedAngle = nil; isHoveringAllocation = false }
    }

    private func financialPosition(_ value: NetWorthChartProjection) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("Your financial picture").font(theme.typography.rowTitle)
            positionChart(value)
        }
    }

    private func positionChart(_ value: NetWorthChartProjection) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack(alignment: .firstTextBaseline) {
                Text("Assets and debt").font(theme.typography.rowTitle)
                Spacer(minLength: theme.spacing.small)
                Text("Chart scale · " + currency.rawValue)
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Text("Assets add to your estimate. Debt subtracts.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            let coordinates = value.rows.compactMap(\.coordinate)
            let lower = min(0, coordinates.min() ?? 0)
            let upper = max(0, coordinates.max() ?? 0)
            let domain = lower == upper ? -1.0...1.0 : (lower * 1.05)...(upper * 1.05)
            ForEach(value.rows) { row in
                Button { toggle(row) } label: {
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        rowLabel(row, color: positionColor(row))
                        if let amount = row.coordinate {
                            Chart {
                                BarMark(xStart: .value("Zero", 0), xEnd: .value(currency.rawValue, amount),
                                        y: .value("Position", title(row)), height: .fixed(20))
                                    .foregroundStyle(positionColor(row))
                                    .cornerRadius(3)
                                    .accessibilityLabel(Text(title(row)))
                                    .accessibilityValue(Text(row.amount?.display ?? "Unavailable"))
                                RuleMark(x: .value("Zero", 0)).foregroundStyle(theme.palette.secondaryText)
                            }
                            .chartXScale(domain: domain)
                            .chartXAxis(.hidden).chartYAxis(.hidden)
                            .frame(height: 24)
                            .allowsHitTesting(false)
                        }
                    }
                    .padding(.vertical, theme.spacing.micro)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilitySummary(row))
                .accessibilityIdentifier("netWorth.chart.row." + row.id)
                .help("Show the accounts or holdings behind this amount")
                .popover(isPresented: detailsPresented(row)) { detailPopover(row) }
            }
        }
    }

    private func allocationChart(_ value: NetWorthChartProjection) -> some View {
        let priced = value.rows.filter { ($0.coordinate ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("Where your investments sit").font(theme.typography.rowTitle)
            Text("Share of investments with an available value")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if !priced.isEmpty && value.rows.allSatisfy({ ($0.coordinate ?? 0) >= 0 }) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.sectionGap) {
                        allocationRing(priced).frame(width: 220, height: 240)
                        allocationLegend(value).frame(minWidth: 230, maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                        allocationRing(priced).frame(height: 240)
                        allocationLegend(value)
                    }
                }
            } else {
                allocationLegend(value)
                if priced.isEmpty {
                    Text("An allocation chart will appear when investment values are available.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                } else {
                    Text("Signed positions are listed individually; they cannot be shown as shares of a whole.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
            }
            if value.missingCount > 0 {
                Label("\(value.missingCount) \(value.missingCount == 1 ? "holding is" : "holdings are") missing a value and left out of the ring.",
                      systemImage: "exclamationmark.circle")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Text("Values use recorded holdings and current prices, not acquisition cost.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func allocationRing(_ rows: [NetWorthChartProjection.Row]) -> some View {
        Chart(rows) { row in
            SectorMark(angle: .value(currency.rawValue, row.coordinate ?? 0),
                       innerRadius: .ratio(0.65), angularInset: 2)
                .cornerRadius(4)
                .foregroundStyle(allocationColor(row))
                .opacity(hoveredAllocationRow == nil || hoveredAllocationRow?.id == row.id ? 1 : 0.65)
                .accessibilityLabel(Text(title(row)))
                .accessibilityValue(Text([row.amount?.display, row.shareOfPricedValue].compactMap { $0 }.joined(separator: ", ")))
        }
        .chartAngleSelection(value: $selectedAngle)
        .chartBackground { _ in
            VStack(spacing: theme.spacing.small) {
                if let row = hoveredAllocationRow {
                    Text(row.shareOfPricedValue ?? currency.rawValue)
                        .font(theme.typography.rowTitle).monospacedDigit()
                    Text(title(row)).font(theme.typography.secondary)
                } else {
                    Text("Priced\nholdings").font(theme.typography.rowTitle)
                    Text(currency.rawValue).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onHover { inside in
            isHoveringAllocation = inside
            if !inside { selectedAngle = nil }
        }
        .overlay(alignment: .topTrailing) {
            if let row = hoveredAllocationRow {
                allocationPreview(row)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Investment allocation in " + currency.rawValue)
        .accessibilityIdentifier("netWorth.chart.allocation")
    }

    private func allocationLegend(_ value: NetWorthChartProjection) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            ForEach(value.rows) { row in
                Button { toggle(row) } label: {
                    rowLabel(row, color: allocationColor(row), showsShare: true)
                        .padding(.vertical, theme.spacing.micro)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilitySummary(row))
                .accessibilityIdentifier("netWorth.chart.row." + row.id)
                .help("Show the holdings behind this allocation")
                .popover(isPresented: detailsPresented(row)) { detailPopover(row) }
            }
        }
    }

    private func rowLabel(_ row: NetWorthChartProjection.Row, color: Color, showsShare: Bool = false) -> some View {
        HStack(alignment: .top, spacing: theme.spacing.small) {
            Circle().fill(row.amount == nil ? theme.palette.secondaryText : color)
                .frame(width: 9, height: 9).padding(.top, 5).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title(row)).font(theme.typography.body)
                    Spacer(minLength: theme.spacing.small)
                    if showsShare, let share = row.shareOfPricedValue {
                        Text(share).font(theme.typography.body.weight(.semibold)).monospacedDigit()
                    }
                    Image(systemName: selectedRow == row.id ? "chevron.down" : "chevron.right")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sectionGap) {
                        convertedAmounts(row)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.micro) { convertedAmounts(row) }
                }
                if row.missingCount > 0 {
                    Text("Known subtotal · \(row.missingCount) unavailable")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
                if row.id == "Cards:net", (row.coordinate ?? 0) > 0 {
                    Text("Combined cards have a net credit balance").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
        .foregroundStyle(theme.palette.primaryText)
    }

    private func convertedAmounts(_ row: NetWorthChartProjection.Row) -> some View {
        ForEach(convertedValues[row.id] ?? []) { value in
            Text(value.display).font(theme.typography.rowTitle.weight(.semibold)).monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func title(_ row: NetWorthChartProjection.Row) -> String {
        switch row.id {
        case "Bank:positive": "Bank balances"
        case "Bank:negative": "Overdrawn bank accounts"
        case "Cards:net": "Total card liability"
        case "Investments:positive": "Investments"
        case "Investments:negative": "Investment liabilities"
        case "Bank:missing": "Bank balances unavailable"
        case "Cards:missing": "Card balances unavailable"
        case "Investments:missing": "Investments without a value"
        default: row.title == "Indian MF" ? "Indian mutual funds" : row.title == "ISP" ? "Zurich ISP" : row.title
        }
    }

    private func allocationColor(_ row: NetWorthChartProjection.Row) -> Color {
        // Consistent native series colors; labels and amounts carry meaning too.
        switch row.title {
        case "ISP": .cyan
        case "IBKR": .indigo
        case "Indian MF": .orange
        case "CBQ Investments": .mint
        default: theme.palette.secondaryText
        }
    }

    private func positionColor(_ row: NetWorthChartProjection.Row) -> Color {
        if (row.coordinate ?? 0) < 0 { return theme.financialNegative }
        switch row.id {
        case "Bank:positive": return .mint
        case "Cards:net": return .cyan
        case "Investments:positive": return .indigo
        default: return theme.palette.secondaryText
        }
    }

    private func accessibilitySummary(_ row: NetWorthChartProjection.Row) -> String {
        [title(row), (convertedValues[row.id] ?? []).map(\.display).joined(separator: ", "), row.shareOfPricedValue,
         row.missingCount > 0 ? "\(row.missingCount) unavailable" : nil,
         selectedRow == row.id ? "Hide details" : "Show details"].compactMap { $0 }.joined(separator: ", ")
    }

    private func toggle(_ row: NetWorthChartProjection.Row) {
        selectedAngle = nil
        selectedRow = selectedRow == row.id ? nil : row.id
    }

    private var hoveredAllocationRow: NetWorthChartProjection.Row? {
        guard isHoveringAllocation, let selectedAngle, let allocation else { return nil }
        var end = 0.0
        for row in allocation.rows {
            guard let value = row.coordinate, value > 0 else { continue }
            end += value
            if selectedAngle <= end { return row }
        }
        return nil
    }

    private func allocationPreview(_ row: NetWorthChartProjection.Row) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title(row)).font(theme.typography.body.weight(.semibold))
            if let share = row.shareOfPricedValue {
                Text(share + " of investments")
                    .font(theme.typography.body.weight(.semibold)).monospacedDigit()
            }
            ForEach(convertedValues[row.id] ?? []) { value in
                Text(value.display).font(theme.typography.body).monospacedDigit()
            }
        }
        .foregroundStyle(theme.palette.primaryText)
        .padding(theme.spacing.controlGap)
        .background(theme.palette.contentSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
        .overlay { RoundedRectangle(cornerRadius: theme.radius.control).strokeBorder(theme.palette.border, lineWidth: 1) }
        .fixedSize()
    }

    private func detailsPresented(_ row: NetWorthChartProjection.Row) -> Binding<Bool> {
        Binding(get: { selectedRow == row.id }, set: { presented in
            if presented { selectedRow = row.id }
            else if selectedRow == row.id { selectedRow = nil }
        })
    }

    private func detailPopover(_ row: NetWorthChartProjection.Row) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack {
                Text(title(row)).font(theme.typography.rowTitle)
                Spacer(minLength: theme.spacing.controlGap)
                Button("Close details", systemImage: "xmark") { selectedRow = nil }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            ViewThatFits(in: .vertical) {
                detail(row).fixedSize(horizontal: false, vertical: true)
                ScrollView { detail(row) }.frame(height: 380)
            }.frame(maxHeight: 420)
        }
        .padding(theme.spacing.panelPadding)
        .frame(width: 520)
        .foregroundStyle(theme.palette.primaryText)
    }

    private func detail(_ row: NetWorthChartProjection.Row) -> some View {
        let ids = Set(row.componentIDs)
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            ForEach(report.members.filter { row.memberIDs.contains($0.id) }) { member in
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text(member.title).font(theme.typography.body.weight(.semibold))
                    Text(member.context).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    ForEach(member.components.filter { ids.contains($0.id) }) { component in
                        VStack(alignment: .leading, spacing: theme.spacing.micro) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(component.title)
                                Spacer(minLength: theme.spacing.small)
                                VStack(alignment: .trailing, spacing: theme.spacing.micro) {
                                    ForEach(convertedValues["component:" + component.id] ?? []) { value in
                                        Text(value.display).monospacedDigit()
                                    }
                                }
                            }
                            .font(theme.typography.body)
                            Text(InvestmentArithmetic.displayedMoney(component.nativeValue, currency: component.currency)
                                 + " · " + component.dateContext)
                                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                            if let quote = component.quote {
                                Text("Price dated \(AppDateDisplay.civil(quote.valuationDay)) · \(quote.dateBasis.label)")
                                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                            }
                            if let issue = component.issue {
                                Text(issue).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                            }
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func refresh() {
        position = .make(report: report, currency: currency, scope: .position)
        allocation = .make(report: report, currency: currency, scope: .allocation)
        var values: [String: [NetWorthChartProjection.ConvertedValue]] = [:]
        for row in (position?.rows ?? []) + (allocation?.rows ?? []) {
            values[row.id] = NetWorthChartProjection.convertedValues(report: report, componentIDs: Set(row.componentIDs))
        }
        for component in report.members.filter(\.isIncluded).flatMap(\.components) {
            values["component:" + component.id] = NetWorthChartProjection.convertedValues(report: report, componentIDs: [component.id])
        }
        convertedValues = values
        if let selectedRow, !(position?.rows.contains { $0.id == selectedRow } ?? false),
           !(allocation?.rows.contains { $0.id == selectedRow } ?? false) { self.selectedRow = nil }
        selectedAngle = nil
    }
}
