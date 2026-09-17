import AppKit
import SwiftUI

private func investmentTextWidth(_ values: [String], role: LFFontRole, theme: LFTheme) -> CGFloat {
    let font = theme.typography.nativeFont(role, tabularDigits: true)
    return ceil(values.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0)
}

struct InvestmentOverviewView: View {
    @Environment(\.lfTheme) private var theme
    let overview: InvestmentOverview
    let viewPortfolioHoldings: (InvestmentPortfolioSummary) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                LFPanel(title: "Investment overview") {
                    overallSummary
                    overviewStatus(now: context.date)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 460), spacing: theme.spacing.sectionGap)],
                          alignment: .leading, spacing: theme.spacing.sectionGap) {
                    ForEach(overview.portfolios) { portfolio in
                        portfolioCard(portfolio, now: context.date)
                    }
                }

                DisclosureGroup("Valuation and currency basis") {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("Current unrealised comparison uses supported acquisition cost and the same current FX basis for value and cost. It is not historical currency performance.")
                        Text("ISP statements do not report fund acquisition costs.")
                        ForEach(AlDarCurrency.allCases, id: \.self) { currency in
                            if let leg = overview.fxLegs[currency] {
                                Text("Al Dar · QAR 1 = \(leg.returned.rawToken) \(currency.rawValue) · fetched \(leg.fetchedAtISO)")
                            }
                        }
                        Text("Native quantities, costs, prices, provider dates and individual policy ownership are available in holding Details.")
                    }
                    .textSelection(.enabled)
                    .padding(.top, theme.spacing.micro)
                }
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            }
            .foregroundStyle(theme.palette.primaryText)
            .padding(.trailing, theme.spacing.micro)
        }
    }

    private var overallSummary: some View {
        ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        valueHero(scope: overview.total, nativeCurrency: "USD", title: "Current value")
                        moneyMeasure("Invested cost", scope: overview.total, nativeCurrency: "USD", field: \.cost)
                        moneyMeasure("Gain / loss", scope: overview.total, nativeCurrency: "USD", field: \.gain, profit: true)
                        returnMeasure(overview.total)
                }
                Text(costPerformanceScope(overview.total))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 900, maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                valueHero(scope: overview.total, nativeCurrency: "USD", title: "Current value")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        moneyMeasure("Invested cost", scope: overview.total, nativeCurrency: "USD", field: \.cost)
                        moneyMeasure("Gain / loss", scope: overview.total, nativeCurrency: "USD", field: \.gain, profit: true)
                        returnMeasure(overview.total)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                        moneyMeasure("Invested cost", scope: overview.total, nativeCurrency: "USD", field: \.cost)
                        moneyMeasure("Gain / loss", scope: overview.total, nativeCurrency: "USD", field: \.gain, profit: true)
                        returnMeasure(overview.total)
                    }
                }
                Text(costPerformanceScope(overview.total))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func portfolioCard(_ portfolio: InvestmentPortfolioSummary, now: Date) -> some View {
        LFPanel(title: portfolio.group.rawValue, trailing: holdingsAction(for: portfolio)) {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                valueHero(scope: portfolio.scope, nativeCurrency: nativeCurrency(for: portfolio), title: "Current value", spreadEquivalent: true)

                if portfolio.group == .isp {
                    ispReportedSummary
                }
                if portfolio.group != .isp || portfolio.scope.costCount > 0 {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                            moneyMeasure("Invested cost", scope: portfolio.scope, nativeCurrency: nativeCurrency(for: portfolio), field: \.cost)
                            moneyMeasure("Gain / loss", scope: portfolio.scope, nativeCurrency: nativeCurrency(for: portfolio), field: \.gain, profit: true)
                        }
                        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                            moneyMeasure("Invested cost", scope: portfolio.scope, nativeCurrency: nativeCurrency(for: portfolio), field: \.cost)
                            moneyMeasure("Gain / loss", scope: portfolio.scope, nativeCurrency: nativeCurrency(for: portfolio), field: \.gain, profit: true)
                        }
                    }
                    percentageMeasures(scope: portfolio.scope, capitalShare: portfolio.capitalShare,
                                       profitShare: portfolio.profitShare, portfolio: portfolio)
                    Text(costPerformanceScope(portfolio.scope))
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                portfolioStatus(portfolio.scope, now: now)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    /// One large native amount gives the eye a clear first reading. The converted
    /// equivalent remains adjacent, quieter, and fully visible.
    private func valueHero(scope: InvestmentOverviewScope, nativeCurrency: String, title: String, spreadEquivalent: Bool = false) -> some View {
        let lines = orderedLines(scope, nativeCurrency: nativeCurrency)
        let valueTitle = scope.priceCount < scope.holdingCount ? "Priced holdings value" : title
        return Group {
            if spreadEquivalent, let equivalent = lines.dropFirst().first {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                        heroAmount(lines.first, title: valueTitle, count: scope.priceCount, emphasized: true)
                        heroAmount(equivalent, title: "Equivalent", count: scope.priceCount, emphasized: false)
                    }
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        heroAmount(lines.first, title: valueTitle, count: scope.priceCount, emphasized: true)
                        heroAmount(equivalent, title: "Equivalent", count: scope.priceCount, emphasized: false)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    heroAmount(lines.first, title: valueTitle, count: scope.priceCount, emphasized: true)
                    ForEach(lines.dropFirst()) { line in
                        Text(line.value?.covering(scope.priceCount)?.display ?? "—")
                            .font(theme.typography.tableMoney)
                            .monospacedDigit()
                            .foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: true, vertical: false)
                            .accessibilityLabel("\(line.currency) equivalent \(line.value?.covering(scope.priceCount)?.display ?? "Unavailable")")
                    }
                }
            }
        }
        .frame(minWidth: investmentTextWidth(lines.dropFirst().map { $0.value?.covering(scope.priceCount)?.display ?? "—" }, role: .tableMoney, theme: theme), maxWidth: .infinity, alignment: .leading)
    }

    private func heroAmount(_ line: InvestmentOverviewLine?, title: String, count: Int, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            amountText(line?.value?.covering(count), emphasized: emphasized)
                .foregroundStyle(emphasized ? theme.palette.primaryText : theme.palette.secondaryText)
                .accessibilityLabel("\(line?.currency ?? "") \(title) \(line?.value?.covering(count)?.display ?? "Unavailable")")
        }
        .frame(minWidth: investmentTextWidth([line?.value?.covering(count)?.display ?? "—"], role: emphasized ? .headlineMoney : .tableMoney, theme: theme), maxWidth: .infinity, alignment: .leading)
    }

    private func moneyMeasure(
        _ title: String,
        scope: InvestmentOverviewScope,
        nativeCurrency: String,
        field: KeyPath<InvestmentOverviewLine, InvestmentConvertedAmount?>,
        profit: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            ForEach(orderedLines(scope, nativeCurrency: nativeCurrency)) { line in
                amountText(line[keyPath: field]?.covering(field == \.cost ? scope.costCount : scope.gainCount), profit: profit)
                    .accessibilityLabel("\(line.currency) \(title) \(line[keyPath: field]?.covering(field == \.cost ? scope.costCount : scope.gainCount)?.display ?? "Unavailable")")
            }
        }
        .frame(minWidth: investmentTextWidth(scope.lines.map { $0[keyPath: field]?.covering(field == \.cost ? scope.costCount : scope.gainCount)?.display ?? "—" }, role: .tableMoney, theme: theme), maxWidth: .infinity, alignment: .leading)
    }

    /// Return is defined on the priced, cost-backed portion. Shares are always
    /// visible and label that same known-cost scope when it is partial.
    private func percentageMeasures(
        scope: InvestmentOverviewScope,
        capitalShare: String?,
        profitShare: String?,
        portfolio: InvestmentPortfolioSummary?
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                percentageMeasure("Return", scope.returnPercent)
                percentageMeasure(capitalLabel(scope, portfolio: portfolio), capitalShare)
                percentageMeasure(profitLabel(scope, portfolio: portfolio), profitShare)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                percentageMeasure("Return", scope.returnPercent)
                percentageMeasure(capitalLabel(scope, portfolio: portfolio), capitalShare)
                percentageMeasure(profitLabel(scope, portfolio: portfolio), profitShare)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func returnMeasure(_ scope: InvestmentOverviewScope) -> some View {
        percentageMeasure("Return", scope.returnPercent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percentageMeasure(_ title: String, _ value: String?) -> some View {
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

    private func capitalLabel(_ scope: InvestmentOverviewScope, portfolio: InvestmentPortfolioSummary?) -> String {
        if portfolio == nil { return "Capital share" }
        return overview.total.hasCompleteCost ? "Share of invested money" : "Share of known invested money"
    }

    private func profitLabel(_ scope: InvestmentOverviewScope, portfolio: InvestmentPortfolioSummary?) -> String {
        let sign = overview.total.usd?.gain?.numerator.sign ?? 0
        let base = sign < 0 ? "Share of net loss" : "Share of net gain"
        if portfolio == nil { return base }
        return overview.total.hasCompleteGain ? base : (sign < 0 ? "Share of known net loss" : "Share of known net gain")
    }

    private var ispReportedSummary: some View {
        Group {
            if let source = overview.ispReported {
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Divider().overlay(theme.palette.divider)
                    Text("Zurich policy figures · \(source.valuationDays.map(InvestmentPriceDates.display).joined(separator: ", "))")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: theme.spacing.sectionGap) {
                            reportedMeasure("Total contributions", source.contributions)
                            reportedMeasure("Reported growth", source.growth, profit: true)
                            if !source.vested.isEmpty { reportedMeasure(source.vestedLabel, source.vested) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            reportedMeasure("Total contributions", source.contributions)
                            reportedMeasure("Reported growth", source.growth, profit: true)
                            if !source.vested.isEmpty { reportedMeasure(source.vestedLabel, source.vested) }
                        }
                    }
                    Text("Policy growth is reported by Zurich. Fund acquisition cost and investment return are unavailable.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
            } else {
                Text("Fund cost and return are unavailable. Connect ISP Account in Settings to see Zurich’s reported contributions and policy growth.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private func reportedMeasure(_ title: String, _ amounts: [InvestmentConvertedAmount], profit: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            ForEach(amounts, id: \.currency) { amount in
                amountText(amount, profit: profit)
                    .accessibilityLabel("\(amount.currency) \(title) \(amount.display)")
            }
            if amounts.isEmpty { amountText(nil) }
        }
        .frame(minWidth: investmentTextWidth(amounts.map(\.display), role: .tableMoney, theme: theme), maxWidth: .infinity, alignment: .leading)
    }

    private func orderedLines(_ scope: InvestmentOverviewScope, nativeCurrency: String) -> [InvestmentOverviewLine] {
        scope.lines.sorted { lhs, rhs in
            if lhs.currency == rhs.currency { return false }
            if lhs.currency == nativeCurrency { return true }
            if rhs.currency == nativeCurrency { return false }
            return lhs.currency < rhs.currency
        }
    }

    private func amountText(_ amount: InvestmentConvertedAmount?, profit: Bool = false, emphasized: Bool = false) -> some View {
        Text(amount?.display ?? "—")
            .font(emphasized ? theme.typography.headlineMoney : theme.typography.tableMoney)
            .monospacedDigit()
            .foregroundStyle(profit ? amount.map { profitColor($0.numerator.sign) } ?? theme.palette.secondaryText : theme.palette.primaryText)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func costPerformanceScope(_ scope: InvestmentOverviewScope) -> String {
        if scope.costCount == scope.holdingCount && scope.gainCount == scope.holdingCount {
            return "Cost, return and shares cover all \(scope.holdingCount) holdings."
        }
        if scope.costCount == scope.gainCount {
            return "Cost, return and shares use the \(scope.costCount) of \(scope.holdingCount) holdings with reported cost."
        }
        return "Cost uses \(scope.costCount) of \(scope.holdingCount) holdings; return and shares use \(scope.gainCount) with both cost and a price."
    }

    private func overviewStatus(now: Date) -> some View {
        status(scope: overview.total, now: now, noun: "holdings", details: "Native values remain available in Details.")
    }

    private func portfolioStatus(_ scope: InvestmentOverviewScope, now: Date) -> some View {
        status(scope: scope, now: now, noun: "holdings", details: "Some converted amounts are unavailable.")
    }

    private func status(scope: InvestmentOverviewScope, now: Date, noun: String, details: String) -> some View {
        let priced = scope.priceCount == scope.holdingCount
            ? "\(scope.holdingCount) \(noun) priced"
            : "Partial: \(scope.priceCount)/\(scope.holdingCount) \(noun) priced"
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(priced).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            freshness(scope, now: now)
            if scope.fxMissing { Text(details).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
        }
    }

    @ViewBuilder private func freshness(_ scope: InvestmentOverviewScope, now: Date) -> some View {
        let age = scope.oldestAge(at: now)
        if !scope.quotes.isEmpty {
            Label(age == 0 ? "Data updated today" : "Oldest data \(age) \(age == 1 ? "day" : "days") ago\(age >= 4 ? " · Stale" : "")", systemImage: "clock")
                .font(theme.typography.caption)
                .foregroundStyle(freshnessColor(age))
        }
    }

    private func profitColor(_ value: Int) -> Color {
        value > 0 ? theme.financialPositive : value < 0 ? theme.financialNegative : theme.palette.primaryText
    }

    private func freshnessColor(_ days: Int) -> Color {
        if days == 0 { return Color(nsColor: .systemGreen) }
        let progress = CGFloat(min(3, max(0, days - 1))) / 3
        return Color(nsColor: NSColor.systemYellow.blended(withFraction: progress, of: .systemRed) ?? .systemRed)
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
                                            if let vested = policy.vestedValue {
                                                Text("Vested value \(InvestmentArithmetic.displayedMoney(vested.amount.value, currency: policy.currency))")
                                            }
                                            Text("Portal valuation \(InvestmentPriceDates.display(policy.valuationDay)) · fetched \(policy.fetchedAt.formatted(.iso8601))")
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
                        Text("\(quote.dateBasis.label) · last successful fetch \(quote.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
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
                Text(age == 0 ? "Currency rates updated today" : "Currency rates \(age) \(age == 1 ? "day" : "days") old\(age >= 4 ? " · Stale" : "")")
                    .foregroundStyle(freshnessColor(age))
            }
        }
        .font(theme.typography.caption)
    }

    private func navPrice(_ fund: InvestmentFundSummary, now: Date) -> some View {
        Group {
            if let quote = fund.quote {
                Text("NAV / price \(MoneyFormatting.unitPrice(quote.price.sourceText, currency: quote.mapping.currency)) · \(InvestmentPriceDates.display(quote.valuationDay))")
                    .foregroundStyle(freshnessColor(quote.age(at: now)))
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
        if days == 0 { return Color(nsColor: .systemGreen) }
        let progress = CGFloat(min(3, max(0, days - 1))) / 3
        return Color(nsColor: NSColor.systemYellow.blended(withFraction: progress, of: .systemRed) ?? .systemRed)
    }
}
