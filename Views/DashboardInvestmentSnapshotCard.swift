import AppKit
import SwiftUI

/// Compact dashboard entry point for the already-built investment overview.
/// It deliberately performs no valuation, source lookup, refresh, or mutation.
struct DashboardInvestmentSnapshotCard: View {
    @Environment(\.lfTheme) private var theme

    let overview: InvestmentOverview
    let report: NetWorthReport
    @Binding var selectedRow: String?
    @State private var showsBasis = false
    let openInvestments: () -> Void

    private var scope: InvestmentOverviewScope { overview.performance }
    private var usd: InvestmentOverviewLine? { scope.usd }
    private var inr: InvestmentOverviewLine? { scope.lines.first { $0.currency == "INR" } }
    private var valueTitle: String { scope.priceCount < scope.holdingCount ? "Priced holdings value" : "Current value" }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            LFPanel(title: "Investments", trailing: AnyView(openButton), contentSpacing: theme.spacing.controlGap) {
                if scope.holdingCount == 0 {
                    emptyContent
                } else {
                    snapshotContent(now: context.date).frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            Text("No investment holdings are imported.")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func snapshotContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            snapshotMetrics
            if report.members.contains(where: { $0.kind == .investment && !$0.isIncluded }) {
                Text("Allocation covers investments included in net worth.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            DashboardReportRows(report: report, scope: .allocation, selectedRow: $selectedRow)
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    freshnessTruth(now: now)
                    Spacer(minLength: theme.spacing.small)
                    basisButton(now: now)
                }
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    freshnessTruth(now: now)
                    basisButton(now: now)
                }
            }
        }
    }

    private func basisButton(now: Date) -> some View {
        Button("Details") { selectedRow = nil; showsBasis = true }
            .buttonStyle(.link)
            .font(theme.typography.secondary)
            .accessibilityIdentifier("dashboard.investmentBasis")
            .popover(isPresented: $showsBasis) {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                        HStack {
                            Text("Investment details").font(theme.typography.rowTitle)
                            Spacer()
                            Button("Close details", systemImage: "xmark") { showsBasis = false }
                                .labelStyle(.iconOnly).buttonStyle(.borderless)
                        }
                        Text("Allocation follows your net-worth inclusion choices. Performance and quote coverage summarize all investment holdings.")
                            .font(theme.typography.secondary)
                        snapshotMetrics
                        coverageTruth
                        freshnessTruth(now: now)
                        if !scope.fxDates.isEmpty {
                            Text(fxAgeText(now: now)).font(theme.typography.secondary)
                        }
                        Text("Source ownership and valuation dates remain unchanged by an FX refresh. Open a portfolio row for individual holdings and source dates.")
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }.padding(theme.spacing.panelPadding)
                }.frame(width: 520, height: 380)
            }
    }

    private var currentValue: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(valueTitle)
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            if let usdValue = usd?.value?.covering(scope.priceCount) {
                Text(usdValue.display)
                    .font(theme.typography.headlineMoney)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("\(valueTitle) in USD: \(usdValue.display)")
                if let inrValue = inr?.value?.covering(scope.priceCount) {
                    Text(inrValue.display)
                        .font(theme.typography.tableMoney)
                        .monospacedDigit()
                        .foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("\(valueTitle) in INR: \(inrValue.display)")
                }
            } else {
                Text("USD current value unavailable")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                if let inrValue = inr?.value?.covering(scope.priceCount) {
                    Text(inrValue.display)
                        .font(theme.typography.tableMoney)
                        .monospacedDigit()
                        .foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("\(valueTitle) in INR: \(inrValue.display)")
                }
            }
        }
    }

    private var snapshotMetrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                currentValue.frame(maxWidth: .infinity, alignment: .leading)
                performanceMetric("Invested / allocated", amount: usd?.cost?.covering(scope.costCount))
                growthMetric
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                currentValue
                performanceMetric("Invested / allocated", amount: usd?.cost?.covering(scope.costCount))
                growthMetric
            }
        }
    }

    private var growthMetric: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            performanceMetric("Gain / growth", amount: usd?.gain?.covering(scope.gainCount), profit: true)
            returnMetric
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performanceMetric(
        _ title: String,
        amount: InvestmentConvertedAmount?,
        profit: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.palette.secondaryText)
            if let amount {
                Text(amount.display)
                    .font(theme.typography.headlineMoney)
                    .monospacedDigit()
                    .foregroundStyle(profit ? profitColor(amount.numerator.sign) : theme.palette.primaryText)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text("Unavailable")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var returnMetric: some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(scope.returnPercent ?? "Unavailable")
                .font(scope.returnPercent == nil ? theme.typography.caption : theme.typography.rowTitle)
                .monospacedDigit()
                .foregroundStyle(scope.returnPercent == nil ? theme.palette.secondaryText
                                 : profitColor(scope.lines.first { $0.gain?.covering(scope.gainCount) != nil && $0.gainCost?.covering(scope.gainCount) != nil }?.gain?.numerator.sign ?? 0))
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Growth percentage: " + (scope.returnPercent ?? "unavailable"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coverageTruth: some View {
        Text(overview.performanceBasis)
        .font(theme.typography.caption)
        .foregroundStyle(theme.palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func freshnessTruth(now: Date) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            if scope.priceCount == 0 {
                Text("No prices available.")
                    .foregroundStyle(theme.palette.secondaryText)
            } else {
                Label(
                    "\(scope.priceCount)/\(scope.holdingCount) prices available · \(quoteAgeText(now: now))",
                    systemImage: "clock"
                )
                .foregroundStyle(freshnessColor(scope.quotes.map { $0.freshnessAge(at: now) }.max() ?? 0))
            }
            if scope.fxMissing {
                Label("Currency conversion unavailable for some totals", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(theme.palette.secondaryText)
            }
        }
        .font(theme.typography.caption)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var openButton: some View {
        Button("Open investments", systemImage: "arrow.right") {
            openInvestments()
        }
        .lfSecondaryAction()
        .accessibilityHint("Opens the Investments section")
    }

    private func quoteAge(now: Date) -> Int {
        scope.quotes.map { $0.age(at: now) }.max() ?? 0
    }

    private func fxAge(now: Date) -> Int {
        scope.fxDates.map { max(0, Int(now.timeIntervalSince($0) / 86_400)) }.max() ?? 0
    }

    private func quoteAgeText(now: Date) -> String {
        ageText(quoteAge(now: now), noun: "oldest")
    }

    private func fxAgeText(now: Date) -> String {
        ageText(fxAge(now: now), noun: "FX refresh")
    }

    private func ageText(_ days: Int, noun: String) -> String {
        days == 0 ? "\(noun) today" : "\(noun) \(days) \(days == 1 ? "day" : "days") ago"
    }

    private func freshnessColor(_ days: Int) -> Color {
        FreshnessTint.color(position: WeekdayFreshness.colorPosition(days: Double(days)))
    }

    private func profitColor(_ sign: Int) -> Color {
        sign > 0 ? theme.financialPositive : sign < 0 ? theme.financialNegative : theme.palette.primaryText
    }
}
