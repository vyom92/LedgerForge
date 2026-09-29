import AppKit
import Charts
import SwiftUI

private func investmentTextWidth(_ values: [String], role: LFFontRole, theme: LFTheme) -> CGFloat {
    let font = theme.typography.nativeFont(role, tabularDigits: true)
    return ceil(values.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0)
}

struct InvestmentOverviewView: View {
    @Environment(\.lfTheme) private var theme
    @State private var expandedDetailsID: String?
    let overview: InvestmentOverview
    let viewPortfolioHoldings: (InvestmentPortfolioSummary) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                LFPanel(title: "Investment overview") {
                    if let comparison = capitalComparison {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: theme.spacing.majorModuleGap) {
                                overviewFigures(now: context.date).frame(minWidth: 560)
                                capitalChart(comparison).frame(width: 340)
                            }
                            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                                overviewFigures(now: context.date)
                                capitalChart(comparison)
                            }
                        }
                    } else {
                        overviewFigures(now: context.date)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 460), spacing: theme.spacing.sectionGap)],
                          alignment: .leading, spacing: theme.spacing.sectionGap) {
                    ForEach(overview.portfolios) { portfolio in
                        portfolioCard(portfolio, now: context.date)
                    }
                }
            }
            .foregroundStyle(theme.palette.primaryText)
            .padding(.trailing, theme.spacing.micro)
        }
    }

    private func overviewFigures(now: Date) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            overallSummary
            inlineAmounts("Invested / contributed",
                          orderedLines(overview.performance, currency: "USD").compactMap { $0.cost?.covering(overview.performance.costCount) })
            partialPerformance(overview.performance)
            status(overview.total, now: now)
            DisclosureGroup("Calculation details", isExpanded: detailsBinding("overview")) {
                valuationDetails.padding(.top, theme.spacing.small)
            }
            .font(theme.typography.secondary)
        }
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
                moneyMeasure("Gain / loss", scope: overview.performance, currency: "USD", field: \.gain, prominent: true)
                percentageMeasure("Growth %", overview.performance.returnPercent, prominent: true, sign: growthSign(overview.performance))
            }
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                valueMeasure(overview.total, currency: "USD")
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                    moneyMeasure("Gain / loss", scope: overview.performance, currency: "USD", field: \.gain, prominent: true)
                    percentageMeasure("Growth %", overview.performance.returnPercent, prominent: true, sign: growthSign(overview.performance))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func portfolioCard(_ portfolio: InvestmentPortfolioSummary, now: Date) -> some View {
        let currency = nativeCurrency(for: portfolio)
        let performance = portfolio.group == .isp ? overview.ispPerformance ?? portfolio.scope : portfolio.scope
        return LFPanel(title: portfolio.group.rawValue, trailing: holdingsAction(for: portfolio)) {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        valueMeasure(portfolio.scope, currency: currency)
                        moneyMeasure(portfolio.group == .isp ? "Growth" : "Gain / loss", scope: performance, currency: currency, field: \.gain, prominent: true)
                        percentageMeasure("Growth %", performance.returnPercent, prominent: true, sign: growthSign(performance))
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                        valueMeasure(portfolio.scope, currency: currency)
                        HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                            moneyMeasure(portfolio.group == .isp ? "Growth" : "Gain / loss", scope: performance, currency: currency, field: \.gain, prominent: true)
                            percentageMeasure("Growth %", performance.returnPercent, prominent: true, sign: growthSign(performance))
                        }
                    }
                }

                Divider().overlay(theme.palette.divider)
                if portfolio.group == .isp {
                    inlineAmounts("Allocated contributions", overview.ispReported?.allocatedContributions ?? [])
                } else {
                    inlineAmounts("Invested cost",
                                  orderedLines(performance, currency: currency).compactMap { $0.cost?.covering(performance.costCount) })
                }
                if portfolio.group == .isp, let source = overview.ispReported, !source.pendingAllocation.isEmpty {
                    inlineAmounts("Pending allocation", source.pendingAllocation)
                        .help("Recorded by Zurich; awaiting fund units. Excluded from current value and growth.")
                }
                partialPerformance(performance)
                status(portfolio.scope, now: now)

                DisclosureGroup("Details", isExpanded: detailsBinding(portfolio.id)) {
                    portfolioDetails(portfolio, performance: performance)
                        .padding(.top, theme.spacing.small)
                }
                .font(theme.typography.secondary)
                .accessibilityIdentifier("investment.details.\(portfolio.id)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                Text(amounts.isEmpty ? "—" : amounts.map(\.display).joined(separator: "  ·  "))
                    .font(theme.typography.tableMoney).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                Text(amounts.isEmpty ? "—" : amounts.map(\.display).joined(separator: "  ·  "))
                    .font(theme.typography.tableMoney).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func partialPerformance(_ scope: InvestmentOverviewScope) -> some View {
        if scope.holdingCount > 0, !scope.hasCompleteGain {
            Text(scope.gainCount == 0 ? "Growth basis unavailable" : "Growth covers \(scope.gainCount) of \(scope.holdingCount) holdings")
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
        let priced = scope.priceCount == scope.holdingCount
            ? "\(scope.holdingCount) holdings priced"
            : "\(scope.priceCount) of \(scope.holdingCount) holdings priced"
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) {
                    Text(priced)
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
            Label(age == 0 ? "Data updated today" : "Oldest data \(age) \(age == 1 ? "day" : "days") ago\(freshness >= 4 ? " · Stale" : "")", systemImage: "clock")
                .foregroundStyle(FreshnessTint.color(position: WeekdayFreshness.colorPosition(days: Double(freshness))))
        }
    }

    private func profitColor(_ value: Int) -> Color {
        value > 0 ? theme.financialPositive : value < 0 ? theme.financialNegative : theme.palette.primaryText
    }
}

struct InvestmentPortfolioDetailView: View {
    @Environment(\.lfTheme) private var theme
    let portfolio: InvestmentPortfolioSummary
    let holdings: [InvestmentHolding]
    let containers: [InvestmentContainer]
    let portfolioNames: [String: String]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    if portfolio.group == .isp && !portfolio.scope.hasCompleteCost {
                        Text("The ISP sources do not report fund acquisition cost, so fund cost, P/L and return are unavailable.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Capital and P/L shares below are within \(portfolio.group.rawValue).")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.palette.secondaryText)
                    }

                    if portfolio.group == .isp, containers.contains(where: { $0.zioSource != nil }) {
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

                    ForEach(portfolio.funds) { fund in
                        fundRow(fund, now: context.date)
                        if fund.id != portfolio.funds.last?.id { Divider().overlay(theme.palette.divider) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, theme.spacing.micro)
            }
        }
    }

    private func fundRow(_ fund: InvestmentFundSummary, now: Date) -> some View {
        let positions = holdings.filter { fund.holdingIDs.contains($0.id) }
        let dates = Array(Set(positions.map(\.holdingsDate))).sorted()
        let dateLabels = Set(positions.map(\.sourceDateLabel))
        let sharedDate = dates.count == 1 && dateLabels.count == 1 ? dates.first.map(InvestmentPriceDates.display) : nil

        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            fundHeading(fund)
            fundWideContent(fund, positions: positions, sharedDate: sharedDate, now: now)
            if portfolio.group == .isp && fund.scope.costCount > 0 { performanceColumn(fund) }
            fundStatus(fund.scope, now: now)

            if let quote = fund.quote {
                DisclosureGroup("Source details") {
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text("\(quote.dateBasis.label) · last successful fetch \(InvestmentPriceDates.fetchInstant(quote.fetchedAt))")
                        Text(quote.qualification)
                    }
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
                    .padding(.top, theme.spacing.micro)
                }
                .font(theme.typography.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, theme.spacing.micro)
    }

    private func fundHeading(_ fund: InvestmentFundSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(fund.name).font(theme.typography.rowTitle)
            Text("Identifier · \(fund.displayIdentifier)")
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
        }
    }

    @ViewBuilder
    private func fundWideContent(
        _ fund: InvestmentFundSummary,
        positions: [InvestmentHolding],
        sharedDate: String?,
        now: Date
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.majorModuleGap) {
                valueAndPriceColumn(fund, now: now)
                    .frame(minWidth: max(220, moneyColumnWidth(fund.scope, field: \.value, emphasized: true)), maxWidth: .infinity, alignment: .leading)
                policyPositionsColumn(fund, positions: positions, sharedDate: sharedDate)
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)
                if portfolio.group == .isp {
                    contributionStrategyColumn(fund, positions: positions)
                        .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
                } else {
                    performanceColumn(fund)
                        .frame(minWidth: max(240, max(moneyColumnWidth(fund.scope, field: \.cost), moneyColumnWidth(fund.scope, field: \.gain))), maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                valueAndPriceColumn(fund, now: now)
                policyPositionsColumn(fund, positions: positions, sharedDate: sharedDate)
                if portfolio.group == .isp {
                    contributionStrategyColumn(fund, positions: positions)
                } else {
                    performanceColumn(fund)
                }
            }
        }
    }

    private func valueAndPriceColumn(_ fund: InvestmentFundSummary, now: Date) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            currentValue(fund)
            Text("\(fund.unitsText) units")
                .font(theme.typography.secondary)
                .monospacedDigit()
            navPrice(fund, now: now)
        }
    }

    private func policyPositionsColumn(
        _ fund: InvestmentFundSummary,
        positions: [InvestmentHolding],
        sharedDate: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text(sharedDate.map { "\(positions.first?.sourceDateLabel ?? "Source date") \($0)" }
                 ?? (portfolio.group == .isp ? "Policy positions and source dates" : "Positions and source dates"))
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            ForEach(positions) { holding in
                compositionRow(holding, showsDate: sharedDate == nil)
            }
        }
    }

    private func contributionStrategyColumn(
        _ fund: InvestmentFundSummary,
        positions: [InvestmentHolding]
    ) -> some View {
        let strategies = observedStrategies(for: fund, positions: positions)
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("Regular contribution split")
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            if !strategies.isEmpty {
                ForEach(strategies, id: \.self) { strategy in
                    Text(strategy)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let strategy = fund.contributionStrategy {
                Text(strategy)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No regular contribution split reported.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func observedStrategies(
        for fund: InvestmentFundSummary,
        positions: [InvestmentHolding]
    ) -> [String] {
        let values = positions.compactMap { holding -> String? in
            guard let policy = containers.first(where: { $0.id == holding.containerID })?.zioSource,
                  let strategy = policy.regularStrategy.first(where: { $0.code == fund.code }) else { return nil }
            return "\(policy.displayName) · \(strategy.percentage.sourceText)% · effective \(InvestmentPriceDates.display(strategy.effectiveDay))"
        }
        return Array(Set(values)).sorted()
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
            ? "\(scope.holdingCount) \(scope.holdingCount == 1 ? "position" : "positions") priced"
            : "Partial: \(scope.priceCount)/\(scope.holdingCount) positions priced"
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(priced).foregroundStyle(theme.palette.secondaryText)
            if scope.fxMissing {
                Text("FX incomplete · native values remain available in the holdings table")
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
            currencyValues(scope, field: field, profit: profit)
        }
        .frame(minWidth: moneyColumnWidth(scope, field: field), maxWidth: .infinity, alignment: .leading)
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
                Text(amount?.display ?? "—")
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
