import AppKit
import Charts
import SwiftUI

private func investmentTextWidth(_ values: [String], role: LFFontRole, theme: LFTheme) -> CGFloat {
    let font = theme.typography.nativeFont(role, tabularDigits: true)
    return ceil(values.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0)
}

/// Display-only shares of the current snapshot. Stored money and quantities
/// remain exact; only the bar width crosses into floating-point geometry.
private struct InvestmentAllocationShare {
    let fraction: Double
    let label: String

    init?(numerator: InvestmentArithmetic.Exact, denominator: InvestmentArithmetic.Exact) {
        guard numerator.sign >= 0, denominator.sign > 0,
              let percentage = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator, places: 1, decimalShift: 2),
              let token = try? InvestmentRatioFormatter.rounded(numerator: numerator, denominator: denominator, places: 6),
              let fraction = Double(token), fraction.isFinite, (0...1).contains(fraction) else { return nil }
        self.fraction = fraction
        self.label = "≈" + percentage + "%"
    }

    static func value(_ part: InvestmentOverviewScope, of total: InvestmentOverviewScope) -> Self? {
        guard let amount = part.usd?.value?.covering(part.holdingCount),
              let whole = total.usd?.value?.covering(total.holdingCount),
              let numerator = try? InvestmentArithmetic.product(amount.numerator, whole.denominator),
              let denominator = try? InvestmentArithmetic.product(amount.denominator, whole.numerator) else { return nil }
        return Self(numerator: numerator, denominator: denominator)
    }

    static func units(_ part: Decimal, of total: Decimal) -> Self? {
        guard let numerator = try? InvestmentArithmetic.Exact(part),
              let denominator = try? InvestmentArithmetic.Exact(total) else { return nil }
        return Self(numerator: numerator, denominator: denominator)
    }
}

private func investmentAllocationColor(_ index: Int, theme: LFTheme) -> Color {
    switch index % 4 {
    case 0: theme.palette.focusRing
    case 1: Color(hex: 0x70C7DC)
    case 2: Color(hex: 0xE8B86A)
    default: Color(hex: 0x64BFAF)
    }
}

private struct InvestmentAllocationBar: View {
    @Environment(\.lfTheme) private var theme
    let share: InvestmentAllocationShare?
    let color: Color

    var body: some View {
        HStack(spacing: theme.spacing.controlGap) {
            GeometryReader { geometry in
                Capsule().fill(theme.palette.tableBorder)
                    .overlay(alignment: .leading) {
                        if let share {
                            Capsule().fill(color).frame(width: geometry.size.width * share.fraction)
                        }
                    }
            }.frame(height: 6).accessibilityHidden(true)
            Text(share?.label ?? "Unavailable")
                .font(theme.typography.secondary.weight(.semibold)).monospacedDigit()
                .foregroundStyle(share == nil ? theme.palette.secondaryText : color)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current value allocation")
        .accessibilityValue(share?.label ?? "Unavailable")
    }
}

struct InvestmentOverviewView: View {
    @Environment(\.lfTheme) private var theme
    @State private var expandedDetailsID: String?
    let overview: InvestmentOverview
    let availableWidth: CGFloat
    let viewPortfolioHoldings: (InvestmentPortfolioSummary) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                LFPanel { overallSummary }
                HStack(alignment: .top) {
                    status(overview.total, now: context.date)
                    Spacer(minLength: theme.spacing.small)
                    Button("Calculation details") { expandedDetailsID = "overview" }
                        .buttonStyle(.link)
                        .popover(isPresented: detailsBinding("overview")) {
                            detailsPopover("Calculation details") {
                                valuationDetails
                                if let comparison = capitalComparison { capitalChart(comparison) }
                            }
                        }
                }
                if availableWidth >= allocationAndComparisonMinimumWidth {
                    HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        allocationPanel.frame(width: allocationPanelWidth)
                        comparisonPanel(now: context.date, width: availableWidth - allocationPanelWidth - theme.spacing.sectionGap)
                    }
                } else {
                    allocationPanel
                    comparisonPanel(now: context.date, width: availableWidth)
                }
                if overview.portfolios.contains(where: { $0.group == .isp && $0.scope.holdingCount > 0 }) {
                    Text("ISP growth uses allocated contributions; fund cost and fund-level gain / loss remain unavailable.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
                if let isp = overview.portfolios.first(where: { $0.group == .isp }), isp.scope.holdingCount > 0 {
                    if let pending = overview.ispReported?.pendingAllocation, !pending.isEmpty {
                        LFPanel(contentSpacing: theme.spacing.small) {
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                inlineAmounts("ISP pending allocation", pending)
                                Spacer(minLength: theme.spacing.controlGap)
                                policyDetailsButton(isp)
                            }
                            VStack(alignment: .leading, spacing: theme.spacing.small) {
                                inlineAmounts("ISP pending allocation", pending)
                                policyDetailsButton(isp)
                            }
                        }
                        }
                    } else {
                        HStack { Spacer(); policyDetailsButton(isp) }
                    }
                }
            }
            .foregroundStyle(theme.palette.primaryText)
        }
    }

    private var allocationPanelWidth: CGFloat {
        max(340, min(availableWidth * 0.34, availableWidth - comparisonMinimumWidth - theme.spacing.sectionGap))
    }
    private var allocationAndComparisonMinimumWidth: CGFloat {
        max(1180, 340 + comparisonMinimumWidth + theme.spacing.sectionGap)
    }

    private var allocationPanel: some View {
        LFPanel(title: "Where your value sits", contentSpacing: theme.spacing.controlGap) {
            Text("Portfolio allocation · US dollars")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap * 2) {
                ForEach(Array(overview.portfolios.enumerated()), id: \.element.id) { index, portfolio in
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                        HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                                Circle().fill(investmentAllocationColor(index, theme: theme)).frame(width: 7, height: 7).accessibilityHidden(true)
                                Text(portfolio.group.rawValue).font(theme.typography.rowTitle)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: theme.spacing.small)
                            VStack(alignment: .trailing, spacing: theme.spacing.micro) {
                                portfolioValue(portfolio.scope, currency: "USD", field: \.value)
                                if portfolio.scope.priceCount < portfolio.scope.holdingCount {
                                    Text("\(portfolio.scope.priceCount)/\(portfolio.scope.holdingCount) prices available")
                                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                                }
                            }
                        }
                        InvestmentAllocationBar(share: .value(portfolio.scope, of: overview.total),
                                                color: investmentAllocationColor(index, theme: theme))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("investments.allocation." + portfolio.id)
                }
            }.padding(.vertical, theme.spacing.sectionGap)
            Text("Bars show current allocation, not return.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var comparisonColumnWidths: [CGFloat] {
        let portfolios = overview.portfolios
        return [
            max(125, investmentTextWidth(portfolios.map { $0.group.rawValue }, role: .rowTitle, theme: theme)),
            max(150, investmentTextWidth(portfolios.map { portfolio in
                portfolio.group == .isp
                    ? overview.ispReported?.allocatedContributions.first(where: { $0.currency == "USD" })?.display ?? "Unavailable"
                    : portfolio.scope.lines.first(where: { $0.currency == nativeCurrency(for: portfolio) })?.cost?.covering(portfolio.scope.costCount)?.display ?? "Unavailable"
            }, role: .rowTitle, theme: theme)),
            max(140, investmentTextWidth(portfolios.map { portfolio in
                performance(for: portfolio).lines.first(where: { $0.currency == nativeCurrency(for: portfolio) })?.gain?.covering(performance(for: portfolio).gainCount)?.display ?? "Unavailable"
            }, role: .rowTitle, theme: theme)),
            max(85, investmentTextWidth(portfolios.map { performance(for: $0).returnPercent ?? "Unavailable" }, role: .rowTitle, theme: theme)),
            max(135, investmentTextWidth(["View holdings"], role: .body, theme: theme) + 32)
        ]
    }

    private var comparisonMinimumWidth: CGFloat {
        comparisonColumnWidths.reduce(0, +) + 4 * theme.spacing.controlGap + 2 * theme.spacing.panelPadding
    }

    private func comparisonPanel(now: Date, width: CGFloat) -> some View {
        LFPanel(title: "Cost, contributions & growth", contentSpacing: theme.spacing.controlGap) {
            Text("Each portfolio keeps its reported basis.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if width >= comparisonMinimumWidth {
                portfolioGrid(now: now, width: width)
            } else {
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    ForEach(overview.portfolios) { portfolio in
                        compactPortfolioRow(portfolio, now: now, width: width)
                        if portfolio.id != overview.portfolios.last?.id { Divider() }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func portfolioGrid(now: Date, width: CGFloat) -> some View {
        let extra = max(0, width - comparisonMinimumWidth) / 5
        let columns = comparisonColumnWidths.map { $0 + extra }
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack(spacing: theme.spacing.controlGap) {
                Text("Portfolio").frame(width: columns[0], alignment: .leading)
                Text("Invested / allocated").frame(width: columns[1], alignment: .trailing)
                Text("Gain / growth").frame(width: columns[2], alignment: .trailing)
                Text("Growth").frame(width: columns[3], alignment: .trailing)
                Color.clear.frame(width: columns[4], height: 1).accessibilityHidden(true)
            }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            ForEach(overview.portfolios) { portfolio in
                Divider()
                HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                    portfolioIdentity(portfolio).frame(width: columns[0], alignment: .leading)
                    portfolioCapital(portfolio).frame(width: columns[1], alignment: .trailing)
                    portfolioGrowth(portfolio).frame(width: columns[2], alignment: .trailing)
                    Text(performance(for: portfolio).returnPercent ?? "Unavailable")
                        .font(theme.typography.rowTitle).monospacedDigit().fixedSize()
                        .foregroundStyle(growthSign(performance(for: portfolio)).map(profitColor) ?? theme.palette.secondaryText)
                        .frame(width: columns[3], alignment: .trailing)
                    portfolioActions(portfolio, now: now).frame(width: columns[4], alignment: .trailing)
                }.padding(.vertical, theme.spacing.sectionGap)
            }
        }.fixedSize(horizontal: true, vertical: false)
    }

    private func compactPortfolioRow(_ portfolio: InvestmentPortfolioSummary, now: Date, width: CGFloat) -> some View {
        let metricWidth = width - 2 * theme.spacing.panelPadding
        let metricCount = min(2, max(1, Int((metricWidth + theme.spacing.controlGap) / (200 + theme.spacing.controlGap))))
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack(alignment: .top) {
                portfolioIdentity(portfolio)
                Spacer(minLength: theme.spacing.small)
                portfolioActions(portfolio, now: now)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.controlGap, alignment: .topLeading), count: metricCount), alignment: .leading, spacing: theme.spacing.controlGap) {
                compactPortfolioMetrics(portfolio)
            }
        }.padding(.vertical, theme.spacing.small)
    }

    @ViewBuilder private func compactPortfolioMetrics(_ portfolio: InvestmentPortfolioSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("Invested / allocated").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            portfolioCapital(portfolio, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(portfolio.group == .isp ? "Growth" : "Gain / loss").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            portfolioGrowth(portfolio, alignment: .leading)
            Text(performance(for: portfolio).returnPercent ?? "Percentage unavailable").font(theme.typography.secondary).monospacedDigit()
                .foregroundStyle(growthSign(performance(for: portfolio)).map(profitColor) ?? theme.palette.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performance(for portfolio: InvestmentPortfolioSummary) -> InvestmentOverviewScope {
        portfolio.group == .isp ? overview.ispPerformance ?? portfolio.scope : portfolio.scope
    }

    private func portfolioGrowth(_ portfolio: InvestmentPortfolioSummary, alignment: HorizontalAlignment = .trailing) -> some View {
        let scope = performance(for: portfolio)
        let amount = scope.lines.first(where: { $0.currency == nativeCurrency(for: portfolio) })?.gain?.covering(scope.gainCount)
        return VStack(alignment: alignment, spacing: theme.spacing.micro) {
            Text(amount?.display ?? "Unavailable").font(theme.typography.rowTitle).monospacedDigit().fixedSize()
                .foregroundStyle(amount.map { profitColor($0.numerator.sign) } ?? theme.palette.secondaryText)
            Text(portfolio.group == .isp ? "Contribution growth" : "Gain / loss")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            if !scope.hasCompleteGain {
                Text("\(scope.gainCount)/\(scope.holdingCount) holdings").font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func portfolioIdentity(_ portfolio: InvestmentPortfolioSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(portfolio.group.rawValue).font(theme.typography.rowTitle.weight(.semibold))
            Text("\(portfolio.scope.holdingCount) holdings").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            if portfolio.scope.priceCount < portfolio.scope.holdingCount {
                Text("\(portfolio.scope.priceCount)/\(portfolio.scope.holdingCount) prices available").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }.frame(minWidth: 135, maxWidth: .infinity, alignment: .leading)
    }

    private func portfolioValue(_ scope: InvestmentOverviewScope, currency: String,
                                field: KeyPath<InvestmentOverviewLine, InvestmentConvertedAmount?>, profit: Bool = false,
                                alignment: HorizontalAlignment = .trailing) -> some View {
        let lines = orderedLines(scope, currency: currency)
        let count = field == \.value ? scope.priceCount : field == \.cost ? scope.costCount : scope.gainCount
        return VStack(alignment: alignment, spacing: theme.spacing.micro) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                let amount = line[keyPath: field]?.covering(count)
                Text(amount?.display ?? "Unavailable")
                    .font(index == 0 ? theme.typography.rowTitle : theme.typography.secondary).monospacedDigit()
                    .foregroundStyle(profit && index == 0 ? amount.map { profitColor($0.numerator.sign) } ?? theme.palette.secondaryText
                                     : index == 0 ? theme.palette.primaryText : theme.palette.secondaryText)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(line.currency + " " + (amount?.display ?? "Unavailable"))
            }
            if field == \.gain, !scope.hasCompleteGain {
                Text("\(scope.gainCount)/\(scope.holdingCount) holdings").font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }.frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
    }

    private func portfolioCapital(_ portfolio: InvestmentPortfolioSummary, alignment: HorizontalAlignment = .trailing) -> some View {
        VStack(alignment: alignment, spacing: theme.spacing.micro) {
            if portfolio.group == .isp {
                Text(overview.ispReported?.allocatedContributions.first(where: { $0.currency == "USD" })?.display ?? "Unavailable")
                    .font(theme.typography.rowTitle).monospacedDigit().fixedSize()
            } else {
                let line = portfolio.scope.lines.first { $0.currency == nativeCurrency(for: portfolio) }
                Text(line?.cost?.covering(portfolio.scope.costCount)?.display ?? "Unavailable")
                    .font(theme.typography.rowTitle).monospacedDigit().fixedSize()
            }
            Text(portfolio.group == .isp ? "Allocated contributions" : "Invested cost")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            if portfolio.group != .isp, !portfolio.scope.hasCompleteCost {
                Text("\(portfolio.scope.costCount)/\(portfolio.scope.holdingCount) holdings")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func portfolioActions(_ portfolio: InvestmentPortfolioSummary, now: Date) -> some View {
        VStack(alignment: .trailing, spacing: theme.spacing.micro) {
            Button("View holdings") { viewPortfolioHoldings(portfolio) }.lfSecondaryAction()
                .accessibilityLabel("View " + portfolio.group.rawValue + " holdings")
            Button("Details") { expandedDetailsID = portfolio.id }.buttonStyle(.link)
                .accessibilityLabel(portfolio.group.rawValue + " details")
                .popover(isPresented: detailsBinding(portfolio.id)) {
                    detailsPopover(portfolio.group.rawValue) {
                        portfolioDetails(portfolio, performance: performance(for: portfolio))
                        status(portfolio.scope, now: now)
                    }
                }
        }
    }

    private func policyDetailsButton(_ isp: InvestmentPortfolioSummary) -> some View {
        Button("Policy contributions & portal details") { expandedDetailsID = "policies" }.buttonStyle(.link)
            .popover(isPresented: detailsBinding("policies")) {
                detailsPopover("Policy contributions") { ispReportedDetails }
            }
    }

    private func detailsPopover<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack {
                Text(title).font(theme.typography.rowTitle)
                Spacer()
                Button("Close details", systemImage: "xmark") { expandedDetailsID = nil }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            ScrollView { content().frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(theme.spacing.panelPadding).frame(width: 580, height: 440)
    }

    // These are two current comparison endpoints, not a historical series.
    // Never compare a partial capital baseline with the whole portfolio value.
    private var capitalComparison: (capital: InvestmentConvertedAmount, current: InvestmentConvertedAmount, amounts: [Double])? {
        let scope = overview.performance
        guard scope.hasCompleteCost, scope.hasCompleteGain,
              scope.holdingCount == overview.total.holdingCount,
              overview.total.priceCount == overview.total.holdingCount,
              let capital = scope.usd?.cost?.covering(scope.holdingCount),
              let current = overview.total.usd?.value?.covering(scope.holdingCount),
              scope.usd?.gain?.covering(scope.holdingCount) != nil else { return nil }
        let amounts = [capital, current].compactMap { amount -> Double? in
            guard let token = try? InvestmentRatioFormatter.rounded(numerator: amount.numerator, denominator: amount.denominator, places: 6),
                  let value = Double(token), value.isFinite, value >= 0,
                  (value * 1.15).isFinite else { return nil }
            return value
        }
        guard amounts.count == 2 else { return nil }
        return (capital, current, amounts)
    }

    private func capitalChart(_ comparison: (capital: InvestmentConvertedAmount, current: InvestmentConvertedAmount, amounts: [Double])) -> some View {
        let color = profitColor(overview.performance.usd?.gain?.numerator.sign ?? 0)
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("Capital → current value · USD")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
            Chart {
                ForEach(0..<2, id: \.self) { index in
                    AreaMark(x: .value("Comparison", index), y: .value("USD", comparison.amounts[index]))
                        .foregroundStyle(color.opacity(0.13))
                    LineMark(x: .value("Comparison", index), y: .value("USD", comparison.amounts[index]))
                        .foregroundStyle(color.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Comparison", index), y: .value("USD", comparison.amounts[index]))
                        .foregroundStyle(color)
                        .symbolSize(35)
                }
            }
            .chartXScale(domain: 0...1, range: .plotDimension(padding: 5))
            .chartYScale(domain: 0...max(1, (comparison.amounts.max() ?? 0) * 1.15))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 88)
            .accessibilityHidden(true)
            HStack {
                comparisonEndpoint("Capital", amount: comparison.capital, alignment: .leading)
                Spacer(minLength: theme.spacing.controlGap)
                comparisonEndpoint("Current value", amount: comparison.current, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capital to current value comparison in USD. Capital \(comparison.capital.display). Current value \(comparison.current.display).")
        .help("Current invested cost and allocated contributions compared with current holdings value. This is a capital comparison, not a historical timeline. Pending allocation is excluded.")
    }

    private func comparisonEndpoint(_ title: String, amount: InvestmentConvertedAmount, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text(amount.display).font(theme.typography.tableMoney).monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var overallSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                valueMeasure(overview.total, currency: "USD")
                Divider()
                moneyMeasure("Invested / allocated", scope: overview.performance, currency: "USD", field: \.cost, prominent: true)
                Divider()
                overviewGrowth
            }.fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) { overviewMetrics }
        }
    }

    @ViewBuilder private var overviewMetrics: some View {
        valueMeasure(overview.total, currency: "USD")
        moneyMeasure("Invested / allocated", scope: overview.performance, currency: "USD", field: \.cost, prominent: true)
        overviewGrowth
    }

    private var overviewGrowth: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                moneyMeasure("Gain / growth", scope: overview.performance, currency: "USD", field: \.gain, prominent: true)
                percentageMeasure("Growth", overview.performance.returnPercent, prominent: true, sign: growthSign(overview.performance))
            }
            partialPerformance(overview.performance)
        }
    }

    private func detailsBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { expandedDetailsID == id }, set: { expandedDetailsID = $0 ? id : nil })
    }

    private func holdingsAction(for portfolio: InvestmentPortfolioSummary) -> AnyView {
        AnyView(
            Button("View holdings", systemImage: "list.bullet") { viewPortfolioHoldings(portfolio) }
                .lfSecondaryAction()
                .controlSize(.small)
                .accessibilityLabel("View \(portfolio.group.rawValue) holdings")
        )
    }

    private func nativeCurrency(for portfolio: InvestmentPortfolioSummary) -> String {
        portfolio.group == .indianMF ? "INR" : "USD"
    }

    // The same type scale makes value, gain and percentage equally easy to scan.
    // Secondary currencies stay adjacent without competing with the primary amount.
    private func valueMeasure(_ scope: InvestmentOverviewScope, currency: String) -> some View {
        moneyMeasure(scope.priceCount < scope.holdingCount ? "Priced holdings value" : "Current value",
                     scope: scope, currency: currency, field: \.value, prominent: true)
    }

    private func moneyMeasure(
        _ title: String,
        scope: InvestmentOverviewScope,
        currency: String,
        field: KeyPath<InvestmentOverviewLine, InvestmentConvertedAmount?>,
        prominent: Bool = false
    ) -> some View {
        let lines = orderedLines(scope, currency: currency)
        let count = field == \.value ? scope.priceCount : field == \.cost ? scope.costCount : scope.gainCount
        let amounts = lines.map { $0[keyPath: field]?.covering(count) }
        let profit = field == \.gain
        let primaryRole: LFFontRole = prominent ? .headlineMoney : .tableMoney
        let width = max(investmentTextWidth([amounts.first.flatMap { $0 }?.display ?? "—"], role: primaryRole, theme: theme),
                        investmentTextWidth(amounts.dropFirst().map { $0?.display ?? "—" }, role: .tableMoney, theme: theme))
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title)
                .font(prominent ? theme.typography.body : theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                amountText(amounts[index], profit: profit, prominent: prominent && index == 0, secondary: index > 0)
                    .accessibilityLabel("\(line.currency) \(title) \(amounts[index]?.display ?? "Unavailable")")
            }
        }
        .frame(minWidth: width, maxWidth: .infinity, alignment: .leading)
    }

    private func growthSign(_ scope: InvestmentOverviewScope) -> Int? {
        scope.lines.first { $0.gain?.covering(scope.gainCount) != nil && $0.gainCost?.covering(scope.gainCount) != nil }?.gain?.numerator.sign
    }

    private func percentageMeasure(_ title: String, _ value: String?, prominent: Bool = false, sign: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title)
                .font(prominent ? theme.typography.body : theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(value ?? "—")
                .font(prominent ? theme.typography.headlineMoney : theme.typography.tableMoney)
                .foregroundStyle(value == nil ? theme.palette.secondaryText : sign.map(profitColor) ?? theme.palette.primaryText)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: investmentTextWidth([value ?? "—"], role: prominent ? .headlineMoney : .tableMoney, theme: theme),
               maxWidth: .infinity, alignment: .leading)
    }

    private func inlineAmounts(_ title: String, _ amounts: [InvestmentConvertedAmount]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: theme.spacing.small) {
                Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                Text(amounts.isEmpty ? "Unavailable" : amounts.map(\.display).joined(separator: "  ·  "))
                    .font(theme.typography.tableMoney).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                Text(amounts.isEmpty ? "Unavailable" : amounts.map(\.display).joined(separator: "  ·  "))
                    .font(theme.typography.tableMoney).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func partialPerformance(_ scope: InvestmentOverviewScope) -> some View {
        if scope.holdingCount > 0, !scope.hasCompleteGain {
            Text(scope.gainCount == 0 ? "Growth unavailable" : "Growth covers \(scope.gainCount) of \(scope.holdingCount) holdings")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func portfolioDetails(_ portfolio: InvestmentPortfolioSummary, performance: InvestmentOverviewScope) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                percentageMeasure(overview.performance.hasCompleteCost ? "Share of invested / contributed money" : "Share of known invested money", portfolio.capitalShare)
                percentageMeasure(overview.profitShareLabel, portfolio.profitShare)
            }
            if portfolio.group == .isp {
                ispReportedDetails
            } else {
                Text(costPerformanceScope(performance))
            }
        }
        .font(theme.typography.secondary)
        .foregroundStyle(theme.palette.secondaryText)
        .textSelection(.enabled)
    }

    @ViewBuilder private var ispReportedDetails: some View {
        if let source = overview.ispReported {
            Text("Zurich policy figures · \(source.valuationDays.map(InvestmentPriceDates.display).joined(separator: ", "))")
            Text(overview.ispPerformance == nil
                 ? "Current holdings and the contribution snapshot need to match before growth can be compared."
                 : "Growth compares published holdings with allocated contributions. Pending allocation is excluded from growth and net worth until the new fund units appear.")
            inlineAmounts("Total recorded contributions", source.contributions)
            inlineAmounts("Reported growth at that date", source.growth)
            if !source.vested.isEmpty { inlineAmounts(source.vestedLabel, source.vested) }
        } else {
            Text("Connect ISP Account in Settings to compare current value with Zurich’s reported contributions.")
        }
    }

    private var valuationDetails: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(overview.performanceBasis)
            Text("Value and cost use the same current FX rates. Growth is not annualized or adjusted for withdrawals.")
            Text("ISP uses allocated contributions at policy level. Individual fund acquisition costs remain unavailable.")
            ForEach(AlDarCurrency.allCases, id: \.self) { currency in
                if let leg = overview.fxLegs[currency] {
                    Text("Al Dar · QAR 1 = \(leg.returned.rawToken) \(currency.rawValue) · fetched \(AppDateDisplay.timestamp(leg.fetchedAt, zone: TimeZone(secondsFromGMT: 0)!))")
                }
            }
            Text("Native quantities, costs, prices, source dates and policy ownership are available in holding Details.")
        }
        .font(theme.typography.secondary)
        .foregroundStyle(theme.palette.secondaryText)
        .textSelection(.enabled)
    }

    private func orderedLines(_ scope: InvestmentOverviewScope, currency: String) -> [InvestmentOverviewLine] {
        scope.lines.sorted { lhs, rhs in
            if lhs.currency == rhs.currency { return false }
            if lhs.currency == currency { return true }
            if rhs.currency == currency { return false }
            return lhs.currency < rhs.currency
        }
    }

    private func amountText(_ amount: InvestmentConvertedAmount?, profit: Bool = false, prominent: Bool = false, secondary: Bool = false) -> some View {
        Text(amount?.display ?? "—")
            .font(prominent ? theme.typography.headlineMoney : theme.typography.tableMoney)
            .monospacedDigit()
            .foregroundStyle(profit && !secondary ? amount.map { profitColor($0.numerator.sign) } ?? theme.palette.secondaryText
                             : secondary ? theme.palette.secondaryText : theme.palette.primaryText)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func costPerformanceScope(_ scope: InvestmentOverviewScope) -> String {
        guard scope.holdingCount > 0 else { return "No current holdings in this portfolio." }
        if scope.costCount == scope.holdingCount && scope.gainCount == scope.holdingCount {
            return "Cost, growth and shares cover all \(scope.holdingCount) holdings."
        }
        if scope.costCount == scope.gainCount {
            return "Cost, growth and shares use \(scope.costCount) of \(scope.holdingCount) holdings with reported cost."
        }
        return "Cost uses \(scope.costCount) of \(scope.holdingCount) holdings; growth and shares use \(scope.gainCount) with both cost and a price."
    }

    private func status(_ scope: InvestmentOverviewScope, now: Date) -> some View {
        let priced = "\(scope.priceCount)/\(scope.holdingCount) prices available"
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) {
                    Text(priced).padding(.horizontal, theme.spacing.controlGap).padding(.vertical, theme.spacing.micro)
                        .background(theme.palette.raisedSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
                    freshness(scope, now: now)
                }
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text(priced)
                    freshness(scope, now: now)
                }
            }
            if scope.fxMissing { Text("Some converted amounts are unavailable.") }
        }
        .font(theme.typography.secondary)
        .foregroundStyle(theme.palette.secondaryText)
    }

    @ViewBuilder private func freshness(_ scope: InvestmentOverviewScope, now: Date) -> some View {
        let age = scope.oldestAge(at: now)
        let freshness = scope.oldestFreshnessAge(at: now)
        if !scope.quotes.isEmpty {
            Label(age == 0 ? "Data updated today" : "Oldest data · \(age) \(age == 1 ? "day" : "days")\(freshness >= 4 ? " · Stale" : "")", systemImage: "clock")
                .foregroundStyle(FreshnessTint.color(position: WeekdayFreshness.colorPosition(days: Double(freshness))))
                .padding(.horizontal, theme.spacing.controlGap).padding(.vertical, theme.spacing.micro)
                .background(theme.palette.raisedSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
        }
    }

    private func profitColor(_ value: Int) -> Color {
        value > 0 ? theme.financialPositive : value < 0 ? theme.financialNegative : theme.palette.primaryText
    }
}

struct InvestmentPortfolioDetailView: View {
    @Environment(\.lfTheme) private var theme
    let portfolio: InvestmentPortfolioSummary
    let overview: InvestmentOverview
    let holdings: [InvestmentHolding]
    let containers: [InvestmentContainer]
    let portfolioNames: [String: String]
    let valuations: [String: InvestmentValuation]
    @Binding var selection: String?
    @FocusState private var focusedFund: String?

    private var selectedFund: InvestmentFundSummary? {
        portfolio.funds.first { $0.id == selection } ?? portfolio.funds.first
    }

    var body: some View {
        GeometryReader { viewport in
            let wide = viewport.size.width >= max(1110, (220 + fundUnitsWidth + fundValueWidth + 2 * theme.spacing.panelPadding) / 0.55)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                            LFPanel { portfolioSummary }
                            if wide {
                                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                                    fundAllocationPanel(availableWidth: (viewport.size.width - theme.spacing.sectionGap) * 0.55, proxy: proxy)
                                        .frame(width: (viewport.size.width - theme.spacing.sectionGap) * 0.55)
                                    if let selectedFund {
                                        LFPanel(contentSpacing: theme.spacing.controlGap) { selectedDetail(selectedFund, now: context.date) }
                                    }
                                }
                            } else {
                                fundAllocationPanel(availableWidth: viewport.size.width, proxy: proxy)
                                if let selectedFund {
                                    LFPanel(contentSpacing: theme.spacing.controlGap) { selectedDetail(selectedFund, now: context.date) }
                                }
                            }
                            if portfolio.group == .isp, portfolio.scope.costCount == 0 {
                                Text("Fund acquisition cost and fund-level gain / loss: Unavailable")
                                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                            }
                            if portfolio.group == .isp, containers.contains(where: { $0.zioSource != nil }) {
                                policyDetails
                            }
                        }.padding(.trailing, theme.spacing.micro)
                    }
                }
            }
        }
    }

    private var portfolioSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.sectionGap) { summaryMetrics }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) { summaryMetrics }
        }
    }

    @ViewBuilder private var summaryMetrics: some View {
        amountGroup("\(portfolio.group.rawValue) \(portfolio.scope.priceCount < portfolio.scope.holdingCount ? "priced value" : "current value")", scope: portfolio.scope, field: \.value)
        if portfolio.group == .isp {
            summarySourceAmount("Allocated contributions", amounts: overview.ispReported?.allocatedContributions ?? [])
            if let pending = overview.ispReported?.pendingAllocation, !pending.isEmpty {
                summarySourceAmount("Pending allocation", amounts: pending)
            }
        } else {
            amountGroup("Invested cost", scope: portfolio.scope, field: \.cost)
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                amountGroup("Gain / loss", scope: portfolio.scope, field: \.gain, profit: true)
                Text(portfolio.scope.returnPercent ?? "Return unavailable")
                    .font(theme.typography.secondary).monospacedDigit()
            }
        }
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("\(portfolio.scope.priceCount)/\(portfolio.scope.holdingCount) prices available")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                .padding(.horizontal, theme.spacing.controlGap).padding(.vertical, theme.spacing.micro)
                .background(theme.palette.raisedSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
            Text("\(portfolio.funds.count) fund groups · \(portfolio.group == .indianMF ? "INR" : "USD")")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summarySourceAmount(_ title: String, amounts: [InvestmentConvertedAmount]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Text(amounts.first(where: { $0.currency == "USD" })?.display ?? "Unavailable")
                .font(theme.typography.headlineMoney).monospacedDigit().fixedSize()
            if let amount = amounts.first(where: { $0.currency == "INR" }) {
                Text(amount.display).font(theme.typography.secondary).monospacedDigit().foregroundStyle(theme.palette.secondaryText).fixedSize()
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fundAllocationPanel(availableWidth: CGFloat, proxy: ScrollViewProxy) -> some View {
        LFPanel(title: "Fund allocation", contentSpacing: theme.spacing.controlGap) {
            Text("Share of \(portfolio.group.rawValue) current value · US dollars")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            fundList(availableWidth: availableWidth, proxy: proxy)
            Text("Allocation bars compare fund values; they do not show performance.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                .padding(.top, theme.spacing.controlGap)
        }
    }

    private func fundList(availableWidth: CGFloat, proxy: ScrollViewProxy) -> some View {
        let nameWidth = max(140, availableWidth - 2 * theme.spacing.panelPadding - 2 * theme.spacing.small
                            - 2 * theme.spacing.controlGap - fundUnitsWidth - fundValueWidth)
        let compact = availableWidth < 140 + fundUnitsWidth + fundValueWidth + 2 * theme.spacing.panelPadding
            + 2 * theme.spacing.small + 2 * theme.spacing.controlGap
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            if !compact {
            HStack(spacing: theme.spacing.controlGap) {
                Text("Fund / identifier").frame(width: nameWidth, alignment: .leading)
                Text("Units").frame(width: fundUnitsWidth, alignment: .trailing)
                Text("Current value").frame(width: fundValueWidth, alignment: .trailing)
            }.font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                .padding(.horizontal, theme.spacing.small)
            Divider()
            }
            ForEach(portfolio.funds) { fund in
                fundButton(fund, nameWidth: nameWidth, compact: compact).id(fund.id)
                    .onKeyPress(.downArrow) { moveFund(from: fund.id, by: 1, proxy: proxy); return .handled }
                    .onKeyPress(.upArrow) { moveFund(from: fund.id, by: -1, proxy: proxy); return .handled }
                if fund.id != portfolio.funds.last?.id { Divider() }
            }
        }
    }

    private var fundUnitsWidth: CGFloat {
        max(85, investmentTextWidth(portfolio.funds.map(\.unitsText), role: .body, theme: theme))
    }
    private var fundValueWidth: CGFloat {
        let currency = portfolio.group == .indianMF ? "INR" : "USD"
        return max(145, portfolio.funds.flatMap { fund in
            fund.scope.lines.map { line in
                investmentTextWidth([line.value?.covering(fund.scope.priceCount)?.display ?? "Unavailable"],
                    role: line.currency == currency ? .rowTitle : .secondary, theme: theme)
            }
        }.max() ?? 0)
    }

    private func fundButton(_ fund: InvestmentFundSummary, nameWidth: CGFloat, compact: Bool) -> some View {
        Button {
            selection = fund.id; focusedFund = fund.id
        } label: {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                if compact {
                    fundIdentity(fund)
                    HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                        VStack(alignment: .leading, spacing: theme.spacing.micro) {
                            Text("Units").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                            Text(fund.unitsText).font(theme.typography.body).monospacedDigit().fixedSize()
                        }
                        Spacer(minLength: theme.spacing.small)
                        fundRowValues(fund)
                    }
                } else {
                HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                fundIdentity(fund).frame(width: nameWidth, alignment: .leading)
                Text(fund.unitsText).font(theme.typography.body).monospacedDigit().fixedSize()
                    .frame(width: fundUnitsWidth, alignment: .trailing)
                fundRowValues(fund).frame(width: fundValueWidth, alignment: .trailing)
                }
                }
                InvestmentAllocationBar(share: .value(fund.scope, of: portfolio.scope),
                    color: investmentAllocationColor(portfolio.funds.firstIndex(where: { $0.id == fund.id }) ?? 0, theme: theme))
            }
            .padding(.horizontal, theme.spacing.small).padding(.vertical, theme.spacing.sectionGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedFund?.id == fund.id ? theme.palette.dataSelection : Color.clear,
                        in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay(alignment: .leading) {
                if selectedFund?.id == fund.id {
                    RoundedRectangle(cornerRadius: 2).fill(theme.interaction.focusRing).frame(width: 3).padding(.vertical, 8)
                }
            }.contentShape(Rectangle())
        }.buttonStyle(LFPlainActionStyle()).focusable().focused($focusedFund, equals: fund.id)
            .accessibilityLabel(investmentDisplayTitle(fund.name) + ", " + fund.displayIdentifier + ", " + fund.unitsText
                + " units, " + fund.scope.lines.map { $0.currency + " " + ($0.value?.covering(fund.scope.priceCount)?.display ?? "Unavailable") }.joined(separator: ", ")
                + ", Current value allocation " + (InvestmentAllocationShare.value(fund.scope, of: portfolio.scope)?.label ?? "unavailable"))
            .accessibilityValue(selectedFund?.id == fund.id ? "Selected" : "Not selected")
            .accessibilityIdentifier("investments.fund." + fund.id)
    }

    private func fundIdentity(_ fund: InvestmentFundSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(investmentDisplayTitle(fund.name)).font(theme.typography.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(fund.displayIdentifier).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func fundRowValues(_ fund: InvestmentFundSummary) -> some View {
        let primary = portfolio.group == .indianMF ? "INR" : "USD"
        let ordered = fund.scope.lines.sorted { left, right in
            if left.currency == right.currency { return false }
            if left.currency == primary { return true }
            if right.currency == primary { return false }
            return left.currency < right.currency
        }
        return VStack(alignment: .trailing, spacing: theme.spacing.micro) {
            ForEach(ordered) { line in
                Text(line.value?.covering(fund.scope.priceCount)?.display ?? "Unavailable")
                    .font(line.currency == primary ? theme.typography.rowTitle : theme.typography.secondary)
                    .monospacedDigit().fixedSize()
                    .foregroundStyle(line.currency == primary ? theme.palette.primaryText : theme.palette.secondaryText)
            }
            if fund.scope.priceCount < fund.scope.holdingCount {
                Text("\(fund.scope.priceCount)/\(fund.scope.holdingCount) prices available")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func selectedDetail(_ fund: InvestmentFundSummary, now: Date) -> some View {
        let positions = holdings.filter { fund.holdingIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("Selected fund").font(theme.typography.caption).foregroundStyle(theme.interaction.focusRing)
            Text(investmentDisplayTitle(fund.name)).font(theme.typography.sectionTitle).fixedSize(horizontal: false, vertical: true)
            Text(fund.displayIdentifier + " · " + (fund.quote?.mapping.currency ?? positions.first?.currency ?? "Currency unavailable")
                 + " · \(positions.count) \(positions.count == 1 ? "position" : "positions")")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) { selectedPrice(fund, now: now) }
                VStack(alignment: .leading, spacing: theme.spacing.small) { selectedPrice(fund, now: now) }
            }
            fundStatus(fund.scope, now: now)
            Divider()
            if portfolio.group == .isp {
                policyUnitAllocation(positions, fund: fund)
                Text("Regular split is this fund’s contribution allocation within each policy—not its share of today’s holding.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                if fund.scope.costCount > 0 { performanceColumn(fund) }
            } else {
                Text("Position details").font(theme.typography.rowTitle)
                ForEach(positions) { holding in
                    positionDetail(holding, fund: fund)
                    if holding.id != positions.last?.id { Divider() }
                }
                Divider()
                performanceColumn(fund)
            }
            if let quote = fund.quote {
                DisclosureGroup("Price source details") {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("\(quote.dateBasis.label) · last successful fetch \(InvestmentPriceDates.fetchInstant(quote.fetchedAt))")
                        Text(quote.qualification)
                    }.font(theme.typography.secondary).padding(.top, theme.spacing.small)
                }.font(theme.typography.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func selectedPrice(_ fund: InvestmentFundSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("NAV / price").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Text(fund.quote.map { MoneyFormatting.unitPrice($0.price.sourceText, currency: $0.mapping.currency) } ?? "Unavailable")
                .font(theme.typography.headlineMoney).monospacedDigit().fixedSize()
        }.frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("NAV / price date").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Text(fund.quote.map { InvestmentPriceDates.display($0.valuationDay) } ?? "Unavailable")
                .font(theme.typography.rowTitle).monospacedDigit().fixedSize()
                .foregroundStyle(fund.quote.map { freshnessColor($0.freshnessAge(at: now)) } ?? theme.palette.secondaryText)
        }
    }

    private func policyColor(_ holding: InvestmentHolding) -> Color {
        let policies = containers.filter { $0.zioSource != nil }.sorted { $0.identity < $1.identity }
        let index = policies.firstIndex(where: { $0.id == holding.containerID }) ?? 0
        return investmentAllocationColor(index == 0 ? 1 : index == 1 ? 0 : index, theme: theme)
    }

    private func policyUnitShares(_ positions: [InvestmentHolding], fund: InvestmentFundSummary) -> [String: InvestmentAllocationShare] {
        guard let total = fund.units, total > 0,
              !positions.isEmpty, Set(positions.map(\.id)) == Set(fund.holdingIDs),
              positions.allSatisfy({ $0.units.value >= 0 }),
              let sum = try? positions.reduce(Decimal.zero, { try InvestmentArithmetic.add($0, $1.units.value) }),
              sum == total else { return [:] }
        let shares = positions.compactMap { holding -> (String, InvestmentAllocationShare)? in
            InvestmentAllocationShare.units(holding.units.value, of: total).map { (holding.id, $0) }
        }
        guard shares.count == positions.count else { return [:] }
        return Dictionary(uniqueKeysWithValues: shares)
    }

    private func policyUnitAllocation(_ positions: [InvestmentHolding], fund: InvestmentFundSummary) -> some View {
        let shares = policyUnitShares(positions, fund: fund)
        let unitsWidth = max(80, investmentTextWidth(positions.map { $0.units.sourceText }, role: .body, theme: theme))
        let shareWidth = max(85, investmentTextWidth(shares.values.map(\.label), role: .body, theme: theme))
        let regularWidth = max(95, investmentTextWidth(positions.map { regularSplit($0, fund: fund) }, role: .body, theme: theme))
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text("Policy unit allocation").font(theme.typography.rowTitle)
                Text("Share of this fund’s \(fund.unitsText) units")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            if shares.count == positions.count, !positions.isEmpty {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        ForEach(positions) { holding in
                            if let share = shares[holding.id] {
                                Rectangle().fill(policyColor(holding))
                                    .frame(width: max(0, geometry.size.width - CGFloat(positions.count - 1) * 2) * share.fraction)
                            }
                        }
                    }
                }.frame(height: 16).clipShape(RoundedRectangle(cornerRadius: 4)).accessibilityHidden(true)
            } else {
                Text("Unit allocation unavailable")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    HStack(spacing: theme.spacing.controlGap) {
                        Text("Policy").frame(width: 170, alignment: .leading)
                        Text("Units").frame(width: unitsWidth, alignment: .trailing)
                        Text("Unit share").frame(width: shareWidth, alignment: .trailing)
                        Text("Regular split").frame(width: regularWidth, alignment: .trailing)
                    }.font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    ForEach(positions) { holding in
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                                policyIdentity(holding).frame(width: 170, alignment: .leading)
                                Text(holding.units.sourceText).font(theme.typography.body).monospacedDigit().fixedSize()
                                    .frame(width: unitsWidth, alignment: .trailing)
                                Text(shares[holding.id]?.label ?? "Unavailable").font(theme.typography.body.weight(.semibold))
                                    .monospacedDigit().foregroundStyle(policyColor(holding)).fixedSize()
                                    .frame(width: shareWidth, alignment: .trailing)
                                Text(regularSplit(holding, fund: fund)).font(theme.typography.body).monospacedDigit().fixedSize()
                                    .frame(width: regularWidth, alignment: .trailing)
                            }
                            policySourceDetails(holding)
                        }.padding(.vertical, theme.spacing.small)
                        Divider()
                    }
                }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    ForEach(positions) { holding in
                        policyIdentity(holding)
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                                policyMetrics(holding, fund: fund, share: shares[holding.id])
                            }
                            VStack(alignment: .leading, spacing: theme.spacing.small) {
                                policyMetrics(holding, fund: fund, share: shares[holding.id])
                            }
                        }
                        policySourceDetails(holding)
                        Divider()
                    }
                }
            }
            policyDates(positions, fund: fund)
        }
    }

    private func policyIdentity(_ holding: InvestmentHolding) -> some View {
        let container = containers.first { $0.id == holding.containerID }
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                Circle().fill(policyColor(holding)).frame(width: 7, height: 7).accessibilityHidden(true)
                Text(container?.zioSource?.displayName ?? container?.displayName ?? "Policy unavailable")
                    .font(theme.typography.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            Text("Policy " + (container?.identity ?? "Unavailable"))
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func regularSplit(_ holding: InvestmentHolding, fund: InvestmentFundSummary) -> String {
        containers.first(where: { $0.id == holding.containerID })?.zioSource?.regularStrategy
            .first(where: { $0.code == fund.code }).map { $0.percentage.sourceText + "%" } ?? "Not reported"
    }

    @ViewBuilder private func policyMetrics(_ holding: InvestmentHolding, fund: InvestmentFundSummary, share: InvestmentAllocationShare?) -> some View {
        metric("Units", holding.units.sourceText)
        metric("Unit share", share?.label)
        metric("Regular split", regularSplit(holding, fund: fund))
    }

    private func policySourceDetails(_ holding: InvestmentHolding) -> some View {
        DisclosureGroup("Source details") {
            InvestmentHoldingInlineDetails(holding: holding, valuation: valuations[holding.id],
                container: containers.first { $0.id == holding.containerID },
                portfolioName: portfolioNames[holding.containerID] ?? "Unavailable")
                .padding(.top, theme.spacing.small)
        }.font(theme.typography.secondary)
            .accessibilityLabel("Source details for " + (portfolioNames[holding.containerID] ?? "policy"))
    }

    private func policyDates(_ positions: [InvestmentHolding], fund: InvestmentFundSummary) -> some View {
        let policies = positions.compactMap { holding in containers.first { $0.id == holding.containerID }?.zioSource }
        let valuationDays = Set(policies.map(\.valuationDay)).sorted()
        let splitDays = Set(policies.compactMap { $0.regularStrategy.first { $0.code == fund.code }?.effectiveDay }).sorted()
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            if !valuationDays.isEmpty {
                Text("Portal valuation: " + valuationDays.map(InvestmentPriceDates.display).joined(separator: ", "))
            }
            if !splitDays.isEmpty {
                Text("Split effective: " + splitDays.map(InvestmentPriceDates.display).joined(separator: ", "))
            }
        }.font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
    }

    private func positionDetail(_ holding: InvestmentHolding, fund: InvestmentFundSummary) -> some View {
        let container = containers.first { $0.id == holding.containerID }
        let policy = container?.zioSource
        let strategy = policy?.regularStrategy.first { $0.code == fund.code }
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text(policy?.displayName ?? container?.displayName ?? "Portfolio unavailable").font(theme.typography.body)
                    Text((portfolio.group == .isp ? "Policy " : "Portfolio / Folio ") + (container?.identity ?? "Unavailable"))
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: theme.spacing.micro) {
                    Text("Units").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    Text(holding.units.sourceText).font(theme.typography.body).monospacedDigit().fixedSize()
                }
                if portfolio.group == .isp {
                    VStack(alignment: .trailing, spacing: theme.spacing.micro) {
                        Text("Regular split").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        Text(strategy.map { $0.percentage.sourceText + "%" } ?? "Not reported")
                            .font(theme.typography.body).monospacedDigit().fixedSize()
                    }
                }
            }
            Text(holding.sourceDateLabel + " " + InvestmentPriceDates.display(holding.holdingsDate))
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            if let strategy {
                Text("Contribution split effective " + InvestmentPriceDates.display(strategy.effectiveDay))
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            } else if portfolio.group == .isp, policy == nil, let strategy = fund.contributionStrategy {
                Text(strategy).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            DisclosureGroup("Source details") {
                InvestmentHoldingInlineDetails(holding: holding, valuation: valuations[holding.id], container: container,
                    portfolioName: portfolioNames[holding.containerID] ?? "Unavailable")
                    .padding(.top, theme.spacing.small)
            }.font(theme.typography.secondary)
        }.padding(.vertical, theme.spacing.small)
    }

    private func moveFund(from id: String, by step: Int, proxy: ScrollViewProxy) {
        guard let index = portfolio.funds.firstIndex(where: { $0.id == id }), portfolio.funds.indices.contains(index + step) else { return }
        let next = portfolio.funds[index + step].id
        selection = next; focusedFund = next; proxy.scrollTo(next, anchor: .center)
    }

    private var policyDetails: some View {
        DisclosureGroup("Policy contributions and portal details") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                ForEach(containers.filter { $0.zioSource != nil }) { container in
                    if let policy = container.zioSource {
                        VStack(alignment: .leading, spacing: theme.spacing.micro) {
                            Text(container.displayName + " · " + container.identity).font(theme.typography.rowTitle)
                            Text("Contributions \(InvestmentArithmetic.displayedMoney(policy.contributions.amount.value, currency: policy.currency)) · Portal value \(InvestmentArithmetic.displayedMoney(policy.value.amount.value, currency: policy.currency)) · Reported growth \(InvestmentArithmetic.displayedMoney(policy.growth.amount.value, currency: policy.currency))")
                            if let pending = policy.pendingAllocation, pending > 0, let allocated = policy.allocatedContributions {
                                Text("Allocated contributions \(InvestmentArithmetic.displayedMoney(allocated.amount.value, currency: policy.currency)) · Pending allocation \(InvestmentArithmetic.displayedMoney(pending, currency: policy.currency))")
                            }
                            if let vested = policy.vestedValue {
                                Text("Vested value \(InvestmentArithmetic.displayedMoney(vested.amount.value, currency: policy.currency))")
                            }
                            Text("Portal valuation \(InvestmentPriceDates.display(policy.valuationDay)) · fetched \(AppDateDisplay.timestamp(policy.fetchedAt, zone: TimeZone(secondsFromGMT: 0)!))")
                                .foregroundStyle(theme.palette.secondaryText)
                        }
                    }
                }
                Text("These are policy-level source totals. They do not establish fund acquisition costs. The portal does not supply a separate units-as-of date.")
                    .foregroundStyle(theme.palette.secondaryText)
            }.font(theme.typography.caption).padding(.top, theme.spacing.small)
        }.font(theme.typography.secondary)
    }

    private func performanceColumn(_ fund: InvestmentFundSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("Cost and performance")
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                    amountGroup("Invested cost", scope: fund.scope, field: \.cost)
                    amountGroup("Gain / loss", scope: fund.scope, field: \.gain, profit: true)
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    amountGroup("Invested cost", scope: fund.scope, field: \.cost)
                    amountGroup("Gain / loss", scope: fund.scope, field: \.gain, profit: true)
                }
            }
            returnAndShares(fund)
        }
    }

    private func fundStatus(_ scope: InvestmentOverviewScope, now: Date) -> some View {
        let priced = scope.priceCount == scope.holdingCount
            ? "\(scope.priceCount)/\(scope.holdingCount) prices available"
            : "Partial: \(scope.priceCount)/\(scope.holdingCount) prices available"
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(priced).foregroundStyle(theme.palette.secondaryText)
            if scope.fxMissing {
                Text("Currency conversion incomplete · original values remain available in the holdings table")
                    .foregroundStyle(theme.palette.secondaryText)
            }
            if let oldestFX = scope.fxDates.min() {
                let age = max(0, Int(now.timeIntervalSince(oldestFX) / 86_400))
                let freshness = Int(WeekdayFreshness.seconds(from: oldestFX, to: now) / 86_400)
                Text(age == 0 ? "Currency rates updated today" : "Currency rates \(age) \(age == 1 ? "day" : "days") old\(freshness >= 4 ? " · Stale" : "")")
                    .foregroundStyle(freshnessColor(freshness))
            }
        }
        .font(theme.typography.caption)
    }

    private func navPrice(_ fund: InvestmentFundSummary, now: Date) -> some View {
        Group {
            if let quote = fund.quote {
                Text("NAV / price \(MoneyFormatting.unitPrice(quote.price.sourceText, currency: quote.mapping.currency)) · \(InvestmentPriceDates.display(quote.valuationDay))")
                    .foregroundStyle(freshnessColor(quote.freshnessAge(at: now)))
            } else {
                Text("NAV / price unavailable")
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .font(theme.typography.secondary)
    }

    private func currentValue(_ fund: InvestmentFundSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text("Current value").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            currencyValues(fund.scope, field: \.value, emphasized: true)
        }
    }

    private func amountGroup(
        _ title: String,
        scope: InvestmentOverviewScope,
        field: KeyPath<InvestmentOverviewLine, InvestmentConvertedAmount?>,
        profit: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            currencyValues(scope, field: field, profit: profit, emphasized: true)
        }
        .frame(minWidth: moneyColumnWidth(scope, field: field, emphasized: true), maxWidth: .infinity, alignment: .leading)
    }

    private func returnAndShares(_ fund: InvestmentFundSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                metric("Return", fund.scope.returnPercent)
                metric(portfolio.scope.hasCompleteCost ? "Capital share" : "Known capital share", fund.capitalShareWithinPortfolio)
                metric(profitShareShortLabel, fund.profitShareWithinPortfolio)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                metric("Return", fund.scope.returnPercent)
                metric(portfolio.scope.hasCompleteCost ? "Capital share" : "Known capital share", fund.capitalShareWithinPortfolio)
                metric(profitShareShortLabel, fund.profitShareWithinPortfolio)
            }
        }
    }

    private func moneyColumnWidth(_ scope: InvestmentOverviewScope, field: KeyPath<InvestmentOverviewLine, InvestmentConvertedAmount?>, emphasized: Bool = false) -> CGFloat {
        let primary = portfolio.group == .indianMF ? "INR" : "USD"
        return scope.lines.map { line in
            investmentTextWidth([line[keyPath: field]?.display ?? "—"],
                                role: emphasized && line.currency == primary ? .headlineMoney : .tableMoney, theme: theme)
        }.max() ?? 0
    }

    // Preserve the accepted coverage guard and primary-currency ordering exactly.
    private func currencyValues(
        _ scope: InvestmentOverviewScope,
        field: KeyPath<InvestmentOverviewLine, InvestmentConvertedAmount?>,
        profit: Bool = false,
        emphasized: Bool = false
    ) -> some View {
        let primary = portfolio.group == .indianMF ? "INR" : "USD"
        let expectedCount = field == \.value ? scope.priceCount : (field == \.cost ? scope.costCount : scope.gainCount)
        let ordered = scope.lines.sorted { left, right in
            if left.currency == right.currency { return false }
            if left.currency == primary { return true }
            if right.currency == primary { return false }
            return left.currency < right.currency
        }
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            ForEach(ordered) { line in
                let amount = line[keyPath: field]?.covering(expectedCount)
                Text(amount?.display ?? "Unavailable")
                        .font(emphasized && line.currency == primary ? theme.typography.headlineMoney : theme.typography.tableMoney)
                        .monospacedDigit()
                        .foregroundStyle(profit ? amount.map { profitColor($0.numerator.sign) } ?? theme.palette.secondaryText : (line.currency == primary ? theme.palette.primaryText : theme.palette.secondaryText))
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("\(line.currency) \(amount?.display ?? "Unavailable")")
            }
        }
    }

    private func compositionRow(_ holding: InvestmentHolding, showsDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(portfolioNames[holding.containerID] ?? "Portfolio unavailable")
                .font(theme.typography.secondary)
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                Text(holding.units.sourceText + " units")
                if showsDate { Text("· \(holding.sourceDateLabel) \(InvestmentPriceDates.display(holding.holdingsDate))") }
            }
            .font(theme.typography.caption)
            .foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var profitShareShortLabel: String {
        let basis = (portfolio.scope.usd?.gain?.numerator.sign ?? 0) < 0 ? "net loss" : "net P/L"
        return portfolio.scope.hasCompleteGain ? "\(basis.capitalized) share" : "Known \(basis) share"
    }

    private func profitColor(_ value: Int) -> Color {
        value > 0 ? theme.financialPositive : value < 0 ? theme.financialNegative : theme.palette.primaryText
    }

    private func metric(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(value ?? "—")
                .font(theme.typography.tableMoney)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: max(investmentTextWidth([value ?? "—"], role: .tableMoney, theme: theme),
                             investmentTextWidth(title.split(separator: " ").map(String.init), role: .caption, theme: theme)),
               maxWidth: .infinity, alignment: .leading)
    }

    private func freshnessColor(_ days: Int) -> Color {
        FreshnessTint.color(position: WeekdayFreshness.colorPosition(days: Double(days)))
    }
}
