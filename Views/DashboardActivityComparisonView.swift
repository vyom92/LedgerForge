import SwiftUI
import Charts

/// Native comparison only. Exact values stay in Money; conversion and magnitude
/// scaling are confined to the chart's rendering coordinates.
struct DashboardActivityComparisonView: View {
    @Environment(\.lfTheme) private var theme
    let comparison: DashboardActivityComparison?
    let state: DashboardContentState

    var body: some View {
        LFPanel(title: "Recorded activity", systemImage: "chart.bar.xaxis", contentSpacing: theme.spacing.controlGap) {
            switch state {
            case .loading:
                ProgressView("Loading recorded activity…").controlSize(.small)
            case .unavailable:
                Text("Current transaction activity is unavailable.")
                    .foregroundStyle(theme.palette.secondaryText)
            case .empty:
                Text("No recorded activity. Transactions appear here once imported.")
                    .foregroundStyle(theme.palette.secondaryText)
            case .populated:
                if let comparison {
                    comparisonContent(comparison)
                }
            }
        }
    }

    private func comparisonContent(_ comparison: DashboardActivityComparison) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text(metadata(for: comparison))
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            ForEach(comparison.currencies) { currency in
                if comparison.currencies.count > 1 {
                    Text(currency.currency.code)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                currencyComparison(currency)
            }
            if comparison.withheldRecordCount > 0 {
                Label("\(comparison.withheldRecordCount) transactions have unestablished effects; their totals are withheld.", systemImage: "info.circle")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            Text(coverageContext(for: comparison))
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            Text("Bars scaled within each section")
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func metadata(for comparison: DashboardActivityComparison) -> String {
        let dateRange: String
        if let first = comparison.firstSourceDate, let last = comparison.lastSourceDate {
            dateRange = "\(first.presentation) – \(last.presentation)"
        } else {
            dateRange = "Source dates unavailable"
        }
        let currencies = comparison.currencies.map { $0.currency.code }.joined(separator: ", ")
        return ["\(comparison.recordCount) transactions", dateRange, currencies]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func coverageContext(for comparison: DashboardActivityComparison) -> String {
        let coverage = "Coverage may have gaps · Transfers and settlements may be included"
        guard comparison.undatedRecordCount > 0 else { return coverage }
        return "\(coverage) · \(comparison.undatedRecordCount) transactions without a source date remain included"
    }

    private func currencyComparison(_ currency: DashboardActivityComparison.Currency) -> some View {
        let columnMinimum = currency.domains.map(minimumWidth).max() ?? 0
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            if currency.domains.isEmpty {
                Text("No classified bank or card activity.")
                    .font(theme.typography.secondary)
            } else {
                ViewThatFits(in: .horizontal) {
                    // Preserve the existing column layout; each domain's bars
                    // are normalized independently within that section.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: columnMinimum), spacing: theme.spacing.majorModuleGap, alignment: .leading), count: currency.domains.count), alignment: .leading) {
                        ForEach(currency.domains) { domain in
                            domainComparison(domain)
                        }
                    }
                    .frame(minWidth: columnMinimum * CGFloat(currency.domains.count) + theme.spacing.majorModuleGap * CGFloat(max(0, currency.domains.count - 1)))
                    VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                        ForEach(currency.domains) { domain in
                            domainComparison(domain)
                        }
                    }
                }
            }
        }
    }

    private func domainComparison(_ domain: DashboardActivityComparison.Domain) -> some View {
        let scale = magnitudeScale(for: domain)
        return VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text(domain.domain == .bank ? "Bank movements" : "Card liability movements")
                .font(theme.typography.rowTitle)
            ForEach(domain.series) { series in
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: theme.spacing.valueGutter) {
                            Text(title(for: series.effect)).fixedSize()
                            Spacer(minLength: 0)
                            seriesValue(series).fixedSize()
                        }
                        VStack(alignment: .leading, spacing: theme.spacing.micro) {
                            Text(title(for: series.effect))
                            LFCompleteValue(lineHeight: theme.typography.lineHeight(.tableMoney)) {
                                seriesValue(series)
                            }
                        }
                    }
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.financialEffectColor(series.effect))
                    if let amount = series.amount {
                        Chart {
                            BarMark(
                                xStart: .value("Zero", 0),
                                xEnd: .value("Magnitude", magnitude(amount)),
                                y: .value("Effect", title(for: series.effect))
                            )
                            .foregroundStyle(theme.financialEffectColor(series.effect))
                        }
                        .chartXScale(domain: 0...scale, range: .plotDimension(padding: 0))
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .frame(height: max(10, theme.typography.size(.secondary)))
                        // The full label and exact Money are always visible above.
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func seriesValue(_ series: DashboardActivityComparison.Series) -> some View {
        if let amount = series.amount {
            Text(MoneyFormatting.display(amount)).font(theme.typography.tableMoney)
        } else {
            Text("No classified records").foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func title(for effect: TransactionPresentationEffect) -> String {
        switch effect {
        case .credit: "Inflow"
        case .debit: "Outflow"
        case .increasesAmountOwed: "Increase owed"
        case .decreasesAmountOwed: "Decrease owed"
        case .unknown: "Effect unavailable"
        }
    }

    private func minimumWidth(for domain: DashboardActivityComparison.Domain) -> CGFloat {
        domain.series.reduce(CGFloat(260)) { width, series in
            let labelWidth = (title(for: series.effect) as NSString).size(withAttributes: [.font: theme.typography.nativeFont(.secondary)]).width
            let value = series.amount.map { MoneyFormatting.display($0) } ?? "No classified records"
            let valueWidth = (value as NSString).size(withAttributes: [.font: theme.typography.nativeFont(.tableMoney)]).width
            return max(width, ceil(labelWidth + valueWidth) + theme.spacing.valueGutter)
        }
    }

    private func magnitude(_ amount: Money) -> Double {
        abs(NSDecimalNumber(decimal: amount.amount).doubleValue)
    }

    private func magnitudeScale(for domain: DashboardActivityComparison.Domain) -> Double {
        let maximum = domain.series.compactMap(\.amount).map(magnitude).max() ?? 0
        // An all-zero coordinate range still needs a nondegenerate plot domain;
        // this is not a manufactured Money value or missing partition.
        return maximum > 0 ? maximum : 1
    }
}
