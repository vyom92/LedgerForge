import SwiftUI
import AppKit

/// A report over the already-published projection. Display choices are local;
/// inclusion changes use the existing metadata transaction/hydration lane.
struct DashboardNetWorthCard: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject private var preferences = ReportingCurrencyPreferences.shared
    let report: NetWorthReport
    let workspaceID: String
    let permitsMutation: Bool
    @Binding var selectedRow: String?
    private enum ExpandedSection: Equatable {
        case breakdown(NetWorthMember.Kind?, NetWorthMemberID?)
    }
    @State private var expandedSection: ExpandedSection?
    @State private var showsDetails = false
    @State private var showsBreakdown = false
    @Binding var showsZeroBalances: Bool
    @State private var failure: String?
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pendingChoice: (Bool, NetWorthMemberID, ProviderGenerationToken)?
#endif

    var body: some View {
        LFPanel(contentSpacing: theme.spacing.controlGap) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.sectionGap) {
                    heading
                    Spacer(minLength: theme.spacing.small)
                    reportControls
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    heading
                    reportControls
                }
            }
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
                supporting("No accounts included. Open Report options to include an account or investment container.")
            case .ready:
                totals
                if showsBreakdown {
                    Divider()
                    DashboardReportRows(report: report, scope: .position, selectedRow: $selectedRow,
                        minimumCurrencyColumnWidth: minimumCurrencyColumnWidth)
                }
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: selectedRow) { _, value in if value != nil { showsDetails = false } }
#if DEBUG
        .alert(DevelopmentProfileAcknowledgementPresentation.title,
               isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pendingChoice = nil } })) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) { approveChoice() }
            Button("Cancel", role: .cancel) { challenge = nil; pendingChoice = nil }
        } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }

    private var heading: some View {
        Text("Net worth estimate").font(theme.typography.sectionTitle)
    }

    private var minimumCurrencyColumnWidth: CGFloat {
        report.targets.reduce(CGFloat(148)) { width, target in
            let amountWidth = ((target.amount?.display ?? "Unavailable") as NSString)
                .size(withAttributes: [.font: theme.typography.nativeFont(.headlineMoney, tabularDigits: true)]).width
            let titleWidth = (netWorthCurrencyName(target.currency) as NSString)
                .size(withAttributes: [.font: theme.typography.nativeFont(.caption)]).width
            return max(width, ceil(max(amountWidth, titleWidth)) + theme.spacing.small)
        }
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

    private var reportControls: some View {
        HStack(spacing: theme.spacing.small) {
            if report.state == .ready {
                Button {
                    showsBreakdown.toggle()
                } label: {
                    HStack(spacing: theme.spacing.small) {
                        Text("Breakdown")
                        Image(systemName: showsBreakdown ? "chevron.down" : "chevron.right")
                            .accessibilityHidden(true)
                    }
                }
                .lfSecondaryAction()
                .accessibilityIdentifier("netWorth.breakdown")
                .accessibilityValue(showsBreakdown ? "Expanded" : "Collapsed")
                .accessibilityHint("Show or hide bank, investment and card totals")
            }
            Button("Report options", systemImage: "slider.horizontal.3") { selectedRow = nil; showsDetails.toggle() }
                .lfSecondaryAction()
                .accessibilityIdentifier("netWorth.details")
                .help("Choose display currencies and included accounts; inspect estimate sources")
                .popover(isPresented: $showsDetails) { reportDetails }
        }
    }

    private var totals: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                ForEach(report.targets) { target in
                    total(target)
                        .frame(minWidth: minimumCurrencyColumnWidth, maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .leading) {
                            if target.id != report.targets.first?.id {
                                Rectangle().fill(theme.palette.divider).frame(width: 1)
                                    .offset(x: -theme.spacing.controlGap / 2)
                            }
                        }
                }
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                ForEach(report.targets) { target in
                    total(target).frame(maxWidth: .infinity, alignment: .leading)
                    if target.id != report.targets.last?.id { Divider() }
                }
            }
        }
        .padding(.top, theme.spacing.small)
    }

    private func total(_ target: NetWorthTarget) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(netWorthCurrencyName(target.currency)).font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            Text(target.amount?.display ?? "Unavailable")
                .font(theme.typography.headlineMoney)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Net worth \(target.currency.rawValue): \(target.amount?.display ?? "unavailable"). \(target.label)")
            if let words = target.amount?.amountInWords {
                Text(words)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel("Amount in words: " + words)
            }
            if Set(report.targets.map(\.label)).count > 1 {
                supporting(target.label + (target.missingCount == 0 ? "" : " · \(target.missingCount) unavailable"))
            }
        }
        .multilineTextAlignment(.leading)
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
                HStack {
                    Text("Report options & sources").font(theme.typography.rowTitle)
                    Spacer()
                    Button("Close details", systemImage: "xmark") { showsDetails = false }
                        .labelStyle(.iconOnly).buttonStyle(.borderless)
                }
                currencyMenu
                if !report.members.isEmpty { breakdown }
                ForEach(report.targets) { target in
                    supporting(target.currency.rawValue + ": " + target.label
                        + (target.missingCount == 0 ? "" : " · \(target.missingCount) positions unavailable"))
                }
                supporting("Balances and holdings have different source dates. Transfers may span those dates.")
                ForEach(report.scopeNotes, id: \.self) { supporting($0) }
            if report.historyOnlyCount > 0 {
                supporting("\(report.historyOnlyCount) history-only \(report.historyOnlyCount == 1 ? "account is" : "accounts are") outside current reporting.")
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
        .frame(width: 560, height: 480)
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
        member.title
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

private func netWorthCurrencyName(_ currency: ReportingCurrency) -> String {
    switch currency {
    case .usd: "US dollars"
    case .inr: "Indian rupees"
    case .qar: "Qatari riyals"
    }
}

/// Compact components and allocation reuse the exact report projection. Plotting
/// coordinates affect bar geometry only; source identities own every drill-down.
struct DashboardReportRows: View {
    @Environment(\.lfTheme) private var theme
    let report: NetWorthReport
    let scope: NetWorthChartProjection.Scope
    @Binding var selectedRow: String?
    var minimumCurrencyColumnWidth: CGFloat = 148
    @State private var hoveredRow: String?
    @FocusState private var focusedRow: String?
    @State private var projection: NetWorthChartProjection?
    @State private var convertedValues: [String: [NetWorthChartProjection.ConvertedValue]] = [:]

    private var currency: ReportingCurrency { report.targets.first?.currency ?? .usd }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            if let projection {
                if scope == .position {
                    let rows = projection.rows.sorted { positionOrder($0) < positionOrder($1) }
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            component(row)
                            if row.id != rows.last?.id { Divider().padding(.horizontal, theme.spacing.controlGap) }
                        }
                    }
                } else {
                    allocationRows(projection)
                }
            }
        }
        .onChange(of: report, initial: true) { _, _ in refresh() }
        .onChange(of: selectedRow) { _, _ in hoveredRow = nil }
        .onDisappear {
            hoveredRow = nil
            if scope == .position, let selectedRow, projection?.rows.contains(where: { $0.id == selectedRow }) == true {
                self.selectedRow = nil
            }
        }
    }

    private func positionOrder(_ row: NetWorthChartProjection.Row) -> (Int, Int) {
        let kind = row.id.hasPrefix("Bank:") ? 0 : row.id.hasPrefix("Investments:") ? 1 : 2
        let sign = row.id.hasSuffix(":missing") ? 2 : row.id.hasSuffix(":negative") ? 1 : 0
        return (kind, sign)
    }

    private func component(_ row: NetWorthChartProjection.Row) -> some View {
        Button { toggle(row) } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: theme.spacing.controlGap) {
                    componentLabel(row).frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
                    ForEach(convertedValues[row.id] ?? []) { value in
                        componentValue(value)
                            .frame(minWidth: minimumCurrencyColumnWidth, maxWidth: .infinity, alignment: .trailing)
                    }
                    rowChevron
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    HStack {
                        componentLabel(row)
                        Spacer(minLength: theme.spacing.small)
                        rowChevron
                    }
                    ForEach(convertedValues[row.id] ?? []) { value in
                        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                            Text(netWorthCurrencyName(value.currency)).font(theme.typography.caption)
                                .foregroundStyle(theme.palette.secondaryText)
                            Spacer(minLength: theme.spacing.small)
                            componentValue(value)
                        }
                    }
                }
            }
            .padding(theme.spacing.controlGap)
            .contentShape(Rectangle())
        }
        .buttonStyle(LFPlainActionStyle())
        .focused($focusedRow, equals: row.id)
        .overlay { focusOutline(row) }
        .accessibilityLabel(accessibilitySummary(row))
        .accessibilityIdentifier("netWorth.chart.row." + row.id)
        .help("Show the accounts or holdings behind this amount")
        .popover(isPresented: detailsPresented(row)) { detailPopover(row) }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func componentLabel(_ row: NetWorthChartProjection.Row) -> some View {
        HStack(spacing: theme.spacing.controlGap) {
            Image(systemName: row.id.hasPrefix("Bank:") ? "building.columns" : row.id.hasPrefix("Cards:") ? "creditcard" : "briefcase")
                .font(theme.typography.sectionIcon).frame(width: 24)
                .foregroundStyle(theme.palette.secondaryText).accessibilityHidden(true)
            Text(title(row)).font(theme.typography.body)
                .foregroundStyle(theme.palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func componentValue(_ value: NetWorthChartProjection.ConvertedValue) -> some View {
        VStack(alignment: .trailing, spacing: theme.spacing.micro) {
            Text(value.amount?.display ?? "Unavailable")
                .font(theme.typography.tableMoney).monospacedDigit()
                .foregroundStyle((value.amount?.numerator.sign ?? 0) < 0 ? theme.financialNegative : theme.palette.primaryText)
                .fixedSize(horizontal: true, vertical: false)
            if value.missingCount > 0 {
                Text("\(value.missingCount) unavailable").font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private var rowChevron: some View {
        Image(systemName: "chevron.right").font(theme.typography.caption)
            .foregroundStyle(theme.palette.secondaryText).frame(width: 12)
    }

    private func allocationRows(_ value: NetWorthChartProjection) -> some View {
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("Portfolio allocation · " + currency.rawValue)
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            allocationDistribution(value)
            if value.rows.isEmpty {
                Text(report.state == .ready || report.state == .noIncludedMembers
                     ? "No investment holdings included in this report." : "Allocation is unavailable.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            ForEach(value.rows) { row in
                Button { toggle(row) } label: {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                                allocationName(row)
                                Spacer(minLength: theme.spacing.small)
                                allocationAmount(row)
                            }
                            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                                allocationName(row)
                                allocationAmount(row)
                            }
                        }
                        rowCoverage(row)
                    }
                    .padding(.vertical, theme.spacing.micro)
                    .contentShape(Rectangle())
                }
                .buttonStyle(LFPlainActionStyle())
                .focused($focusedRow, equals: row.id)
                .overlay { focusOutline(row) }
                .onHover { inside in hoveredRow = inside && selectedRow == nil ? row.id : nil }
                .accessibilityLabel(accessibilitySummary(row))
                .accessibilityIdentifier("netWorth.chart.row." + row.id)
                .help("Show the holdings behind this allocation")
                .popover(isPresented: detailsPresented(row)) { detailPopover(row) }
            }
            if value.missingCount > 0 {
                Text("\(value.missingCount) holdings have no available price; percentages cover available values.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
            if !value.rows.isEmpty, value.rows.allSatisfy({ $0.shareOfPricedValue == nil }) {
                Text("Allocation percentages are unavailable for these values.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let row = value.rows.first(where: { $0.id == hoveredRow }) {
                allocationPreview(row).allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("netWorth.chart.allocation")
    }

    @ViewBuilder private func allocationDistribution(_ value: NetWorthChartProjection) -> some View {
        let segments = value.rows.filter { $0.shareOfPricedValue != nil && ($0.coordinate ?? 0) > 0 }
        let total = segments.compactMap(\.coordinate).reduce(0, +)
        if total.isFinite, total > 0 {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(segments) { row in
                        Rectangle()
                            .fill(allocationColor(row))
                            .frame(width: geometry.size.width * ((row.coordinate ?? 0) / total))
                            .overlay(alignment: .trailing) {
                                if row.id != segments.last?.id {
                                    Rectangle().fill(theme.palette.contentSurface).frame(width: 1)
                                }
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
            }
            .frame(height: 16)
            .padding(.vertical, theme.spacing.micro)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Investment distribution in " + currency.rawValue)
            .accessibilityValue(segments.map { title($0) + ": " + ($0.shareOfPricedValue ?? "") }.joined(separator: ", "))
            .accessibilityIdentifier("netWorth.chart.distribution")
        }
    }

    private func allocationName(_ row: NetWorthChartProjection.Row) -> some View {
        HStack(spacing: theme.spacing.small) {
            Circle().fill(allocationColor(row)).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(title(row)).font(theme.typography.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func allocationAmount(_ row: NetWorthChartProjection.Row) -> some View {
        HStack(spacing: theme.spacing.controlGap) {
            Text(row.amount?.display ?? "Unavailable")
                .font(theme.typography.tableMoney).monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
            Text(row.shareOfPricedValue ?? "Share unavailable")
                .font(theme.typography.secondary).monospacedDigit()
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "chevron.right").font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
        }
    }

    @ViewBuilder private func rowCoverage(_ row: NetWorthChartProjection.Row) -> some View {
        if row.missingCount > 0 {
            Text("\(row.missingCount) values unavailable")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    @ViewBuilder private func focusOutline(_ row: NetWorthChartProjection.Row) -> some View {
        if focusedRow == row.id {
            RoundedRectangle(cornerRadius: theme.radius.control)
                .strokeBorder(theme.interaction.focusRing, lineWidth: 2).allowsHitTesting(false)
        }
    }

    private func convertedAmounts(_ row: NetWorthChartProjection.Row) -> some View {
        ForEach(convertedValues[row.id] ?? []) { value in
            Text(value.amount?.display ?? (netWorthCurrencyName(value.currency) + " unavailable"))
                .font(theme.typography.rowTitle.weight(.semibold)).monospacedDigit()
                .accessibilityLabel(value.display)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func title(_ row: NetWorthChartProjection.Row) -> String {
        switch row.id {
        case "Bank:positive": "Bank balances"
        case "Bank:negative": "Overdrawn bank accounts"
        case "Cards:net": (row.coordinate ?? 0) > 0 ? "Card credit balance" : "Card liabilities"
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

    private func accessibilitySummary(_ row: NetWorthChartProjection.Row) -> String {
        [title(row), (convertedValues[row.id] ?? []).map(\.display).joined(separator: ", "), row.shareOfPricedValue,
         row.missingCount > 0 ? "\(row.missingCount) unavailable" : nil,
         selectedRow == row.id ? "Hide details" : "Show details"].compactMap { $0 }.joined(separator: ", ")
    }

    private func toggle(_ row: NetWorthChartProjection.Row) {
        hoveredRow = nil
        selectedRow = selectedRow == row.id ? nil : row.id
    }

    private func allocationPreview(_ row: NetWorthChartProjection.Row) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title(row)).font(theme.typography.body.weight(.semibold))
            if let share = row.shareOfPricedValue {
                Text(share + " of included priced holdings")
                    .font(theme.typography.body.weight(.semibold)).monospacedDigit()
            }
            ForEach(convertedValues[row.id] ?? []) { value in
                Text(value.amount?.display ?? (netWorthCurrencyName(value.currency) + " unavailable"))
                    .font(theme.typography.body).monospacedDigit()
                    .accessibilityLabel(value.display)
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
                                        Text(value.amount?.display ?? (netWorthCurrencyName(value.currency) + " unavailable"))
                                            .monospacedDigit()
                                            .accessibilityLabel(value.display)
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
        let previousIDs = Set(projection?.rows.map(\.id) ?? [])
        projection = .make(report: report, currency: currency, scope: scope)
        var values: [String: [NetWorthChartProjection.ConvertedValue]] = [:]
        for row in projection?.rows ?? [] {
            values[row.id] = NetWorthChartProjection.convertedValues(report: report, componentIDs: Set(row.componentIDs))
        }
        for component in report.members.filter(\.isIncluded).flatMap(\.components) {
            values["component:" + component.id] = NetWorthChartProjection.convertedValues(report: report, componentIDs: [component.id])
        }
        convertedValues = values
        // The two sections share one selection. Only clear a selection this
        // section owned when its backing row has disappeared.
        if let selectedRow, previousIDs.contains(selectedRow),
           !(projection?.rows.contains { $0.id == selectedRow } ?? false) { self.selectedRow = nil }
        hoveredRow = nil
    }
}
