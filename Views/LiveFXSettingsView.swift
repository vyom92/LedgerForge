import SwiftUI

struct LiveFXSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var rates: AlDarReferenceSession
    @ObservedObject var prices: InvestmentPriceSession
    private var refreshing: Bool { !rates.refreshing.isEmpty || !prices.refreshing.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text("Live FX").font(theme.typography.formHeading)
                    Text("Keep shared currency rates and current investment prices up to date.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Button {
                    LiveFXRefreshService(currencyRates: rates, investmentPrices: prices).refreshAll()
                } label: {
                    Label(refreshing ? "Refreshing…" : "Refresh all", systemImage: "arrow.clockwise")
                        .fixedSize()
                }.buttonStyle(LFActionButtonStyle(kind: .primary)).disabled(refreshing)
                .accessibilityIdentifier("liveFX.refreshAll")
            }
            Text("At launch, then 00:00 · 06:00 · 12:00 · 18:00 UTC")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text("One retry after 60 seconds for failed sources. A missed slot is checked once on wake; manual refresh keeps the UTC schedule.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            LFPanel(title: "Currency rates", systemImage: "arrow.left.arrow.right") {
                Text("Al Dar · Shared UTC schedule")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                ForEach(AlDarCurrency.allCases, id: \.self) { currency in
                    HStack(alignment: .firstTextBaseline) {
                        Text("QAR → \(currency.rawValue)").font(theme.typography.rowTitle)
                        if let value = (currency == .inr ? AlDarPair.qarINR : .qarUSD).displayedRate(rates.legs) {
                            Text("1 QAR = \(value) \(currency.rawValue)").font(theme.typography.tableMoney).monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: theme.spacing.micro) {
                            Text(currencyStatus(currency))
                            if let leg = rates.legs[currency] { successTime(leg.fetchedAt) }
                        }.font(theme.typography.secondary)
                    }
                }
                if let feedback = rates.refreshFeedback {
                    Text(feedback.message).font(theme.typography.secondary)
                        .foregroundStyle(feedback.isWarning ? LFTheme.warning : theme.palette.secondaryText)
                }
            }
            LFPanel(title: "Investment NAV / prices", systemImage: "chart.line.uptrend.xyaxis") {
                Text("Shared UTC schedule · Refresh all also checks the latest available prices now.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if prices.rows.isEmpty {
                    Text("No current holdings. Investment sources will become available after importing a statement.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                } else {
                    ForEach(prices.configuredProviders, id: \.self) { provider in providerRow(provider) }
                    if prices.unmappedCount > 0 {
                        Text("\(prices.unmappedCount) holdings need a confirmed price mapping.")
                            .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    }
                }
                if let message = prices.mappingMessage {
                    Text(message).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                }
            }
            Text("Quote dates and successful refresh times are shown separately. ISP prices use your prior-weekday UTC date rule. Last successful values remain visible if a source cannot update.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
        .foregroundStyle(theme.palette.primaryText)
    }

    private func providerRow(_ provider: String) -> some View {
        let mappings = prices.configuredMappings.filter { $0.provider == provider }
        let cached = mappings.compactMap { prices.quotes[$0.identity] }
        let errors = Set(mappings.compactMap { prices.failures[$0.identity]?.localizedDescription }).sorted()
        let isRefreshing = prices.refreshing.contains(provider)
        return VStack(alignment: .leading, spacing: theme.spacing.small) {
            Divider().overlay(theme.palette.divider)
            HStack(alignment: .firstTextBaseline) {
                Text(InvestmentPriceRegistry.providerNames[provider] ?? provider).font(theme.typography.rowTitle)
                Spacer()
                VStack(alignment: .trailing, spacing: theme.spacing.micro) {
                    Text(isRefreshing ? "Refreshing…" : prices.feedback[provider] ?? priceStatus(cached: cached, mappingCount: mappings.count, hasErrors: !errors.isEmpty, isRefreshing: false))
                        .font(theme.typography.secondary)
                    if let fetched = cached.map(\.fetchedAt).max() {
                        successTime(fetched)
                    }
                }
            }
            if provider == "fe" {
                Text("Prior weekday end of day (UTC) · No weekend price updates")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
            ForEach(errors, id: \.self) { error in
                Text(error + (cached.isEmpty ? "" : " Last successful prices remain available."))
                    .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func currencyStatus(_ currency: AlDarCurrency) -> String {
        if rates.refreshing.contains(currency) { return "Refreshing…" }
        if rates.failures.contains(currency) {
            return rates.legs[currency] == nil ? "Couldn’t update" : "Couldn’t update · previous rate retained"
        }
        return rates.legs[currency] == nil ? "No successful rate yet" : "Rate available"
    }

    private func priceStatus(
        cached: [InvestmentQuote],
        mappingCount: Int,
        hasErrors: Bool,
        isRefreshing: Bool
    ) -> String {
        if isRefreshing { return "Refreshing…" }
        if hasErrors { return cached.isEmpty ? "Couldn’t update" : "Couldn’t update · previous prices retained" }
        if cached.isEmpty { return "No successful price yet" }
        return cached.count == mappingCount ? "Prices available" : "Some prices available"
    }

    private func successTime(_ date: Date) -> some View {
        Text("Last successful update \(date.formatted(date: .abbreviated, time: .shortened))")
            .font(theme.typography.caption)
            .foregroundStyle(theme.palette.secondaryText)
    }
}
