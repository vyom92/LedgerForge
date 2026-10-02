import SwiftUI

struct LiveFXSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var rates: AlDarReferenceSession
    @ObservedObject var prices: InvestmentPriceSession
    @ObservedObject var backgroundUpdates: BackgroundUpdatesSession
    var availableWidth: CGFloat = 0
    private var refreshing: Bool { !rates.refreshing.isEmpty || !prices.refreshing.isEmpty }
    private var usesTable: Bool { availableWidth >= max(1040, theme.typography.size(.secondary) * 80) }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFSettingsPageHeader("Live FX", subtitle: "Currency rates and investment prices.") {
                Button {
                    LiveFXRefreshService(currencyRates: rates, investmentPrices: prices).refreshAll()
                } label: {
                    Label(refreshing ? "Refreshing…" : "Refresh all", systemImage: "arrow.clockwise")
                        .fixedSize()
                }
                .lfPrimaryAction().disabled(refreshing)
                .accessibilityIdentifier("liveFX.refreshAll")
            }
            schedulePanel
            currencyPanel
            pricesPanel
            Text("Quote dates and successful refresh times are separate. Last successful values remain visible if a source cannot update.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(theme.palette.primaryText)
    }

    private var schedulePanel: some View {
        LFPanel(contentSpacing: theme.spacing.small) {
            Label(backgroundUpdates.activeSchedule
                  ? "Uses your saved Background Updates schedule"
                  : "At launch · 00:00 / 06:00 / 12:00 / 18:00 UTC", systemImage: "clock")
                .font(theme.typography.rowTitle)
                .fixedSize(horizontal: false, vertical: true)
            Text("Manual refresh keeps the UTC schedule.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            DisclosureGroup("Update rules") {
                Text("One retry after 60 seconds for failed sources. A missed slot is checked once on wake. When Background Updates is active, its saved schedule and enabled scopes apply.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, theme.spacing.small)
            }
            .font(theme.typography.secondary)
            if let message = backgroundUpdates.message {
                Text(message).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var currencyPanel: some View {
        LFPanel(title: "Currency rates", trailing: AnyView(Text("Al Dar")
            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText))) {
            if usesTable {
                Grid(alignment: .leading, horizontalSpacing: theme.spacing.sectionGap,
                     verticalSpacing: theme.spacing.controlGap) {
                    GridRow {
                        columnHeading("Pair")
                        columnHeading("Rate")
                        columnHeading("Status")
                        columnHeading("Successful update · UTC")
                        Color.clear.frame(width: 112, height: 1).accessibilityHidden(true)
                    }
                    ForEach(AlDarCurrency.allCases, id: \.self) { currency in
                        GridRow {
                            Text("QAR → \(currency.rawValue)").font(theme.typography.rowTitle)
                            currencyRate(currency)
                            currencyState(currency)
                            currencyTime(currency)
                            currencyRefresh(currency)
                        }
                        if currency != AlDarCurrency.allCases.last {
                            Divider().overlay(theme.palette.divider).gridCellColumns(5)
                        }
                    }
                }
            } else {
                ForEach(AlDarCurrency.allCases, id: \.self) { currency in
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("QAR → \(currency.rawValue)").font(theme.typography.rowTitle)
                            Spacer()
                            currencyRefresh(currency)
                        }
                        currencyRate(currency)
                        currencyState(currency)
                        currencyTime(currency)
                    }
                    if currency != AlDarCurrency.allCases.last { Divider().overlay(theme.palette.divider) }
                }
            }
            if let feedback = rates.refreshFeedback {
                Text(feedback.message).font(theme.typography.secondary)
                    .foregroundStyle(feedback.isWarning ? LFTheme.warning : theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pricesPanel: some View {
        LFPanel(title: "Investment NAV / prices") {
            if prices.rows.isEmpty {
                Text("No current holdings. Investment sources will become available after importing a statement.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            } else {
                if usesTable {
                    Grid(alignment: .leading, horizontalSpacing: theme.spacing.sectionGap,
                         verticalSpacing: theme.spacing.controlGap) {
                        GridRow {
                            columnHeading("Source")
                            columnHeading("Linked prices available")
                            columnHeading("Successful update · UTC")
                            Color.clear.frame(width: 112, height: 1).accessibilityHidden(true)
                        }
                        ForEach(prices.configuredProviders, id: \.self) { provider in
                            GridRow {
                                providerName(provider)
                                providerState(provider)
                                providerTime(provider)
                                providerRefresh(provider)
                            }
                            providerErrors(provider).gridCellColumns(4)
                            if provider != prices.configuredProviders.last {
                                Divider().overlay(theme.palette.divider).gridCellColumns(4)
                            }
                        }
                    }
                } else {
                    ForEach(prices.configuredProviders, id: \.self) { provider in
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            HStack(alignment: .top) {
                                providerName(provider)
                                Spacer()
                                providerRefresh(provider)
                            }
                            providerState(provider)
                            providerTime(provider)
                            providerErrors(provider)
                        }
                        if provider != prices.configuredProviders.last { Divider().overlay(theme.palette.divider) }
                    }
                }
                if prices.unmappedCount > 0 {
                    Text("\(prices.unmappedCount) holdings have no confirmed price mapping. They are not included in the source results above or the valued total; refreshing cannot price them yet.")
                        .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let message = prices.mappingMessage {
                Text(message).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func columnHeading(_ title: String) -> some View {
        Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func currencyRate(_ currency: AlDarCurrency) -> some View {
        let value = (currency == .inr ? AlDarPair.qarINR : .qarUSD).displayedRate(rates.legs)
        return Text(value.map { "1 QAR = \($0) \(currency.rawValue)" } ?? "No successful rate yet")
            .font(theme.typography.tableMoney).monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    private func currencyState(_ currency: AlDarCurrency) -> some View {
        Text(currencyStatus(currency)).font(theme.typography.secondary)
            .foregroundStyle(rates.failures.contains(currency) ? LFTheme.warning
                             : rates.legs[currency] != nil && !rates.refreshing.contains(currency)
                             ? LFTheme.success : theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func currencyTime(_ currency: AlDarCurrency) -> some View {
        if let date = rates.legs[currency]?.fetchedAt { successTime(date) }
        else { Text("No successful update").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
    }

    private func currencyRefresh(_ currency: AlDarCurrency) -> some View {
        refreshButton(busy: rates.refreshing.contains(currency), label: "Refresh QAR to \(currency.rawValue)",
                      identifier: "liveFX.refresh.aldar.\(currency.rawValue)") {
            backgroundUpdates.refreshCurrency(currency)
        }
    }

    private func providerName(_ provider: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(InvestmentPriceRegistry.providerNames[provider] ?? provider).font(theme.typography.rowTitle)
            if provider == "fe" {
                Text("Prior weekday end · UTC · No weekend updates")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func providerState(_ provider: String) -> some View {
        let mappings = prices.configuredMappings.filter { $0.provider == provider }
        let cached = mappings.compactMap { prices.quotes[$0.identity] }
        let hasErrors = mappings.contains { prices.failures[$0.identity] != nil }
        let isRefreshing = prices.refreshing.contains(provider)
        let complete = cached.count == mappings.count && !cached.isEmpty && !hasErrors && !isRefreshing
        let status = isRefreshing ? "Refreshing…" : hasErrors
            ? (cached.isEmpty ? "Couldn’t update" : "Couldn’t update · previous prices retained")
            : cached.isEmpty ? "No successful price yet" : "\(cached.count) / \(mappings.count)"
        return VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(status)
                .font(theme.typography.rowTitle).monospacedDigit()
                .foregroundStyle(hasErrors ? LFTheme.warning : complete ? LFTheme.success : theme.palette.secondaryText)
            if let feedback = prices.feedback[provider] {
                Text(feedback).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Linked prices available")
        .accessibilityValue([status, prices.feedback[provider]].compactMap { $0 }.joined(separator: ". "))
    }

    @ViewBuilder private func providerTime(_ provider: String) -> some View {
        let dates = prices.configuredMappings.filter { $0.provider == provider }
            .compactMap { prices.quotes[$0.identity]?.fetchedAt }
        if let fetched = dates.max() { successTime(fetched) }
        else { Text("No successful update").font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
    }

    @ViewBuilder private func providerErrors(_ provider: String) -> some View {
        let mappings = prices.configuredMappings.filter { $0.provider == provider }
        let cached = mappings.compactMap { prices.quotes[$0.identity] }
        let errors = Set(mappings.compactMap { prices.failures[$0.identity]?.localizedDescription }).sorted()
        ForEach(errors, id: \.self) { error in
            Text(error + (cached.isEmpty ? "" : " Last successful prices remain available."))
                .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func providerRefresh(_ provider: String) -> some View {
        refreshButton(busy: prices.refreshing.contains(provider),
                      label: "Refresh \(InvestmentPriceRegistry.providerNames[provider] ?? provider)",
                      identifier: "liveFX.refresh.\(provider)") {
            backgroundUpdates.refreshPrices(provider: provider)
        }
    }

    private func currencyStatus(_ currency: AlDarCurrency) -> String {
        if rates.refreshing.contains(currency) { return "Refreshing…" }
        if rates.failures.contains(currency) {
            return rates.legs[currency] == nil ? "Couldn’t update" : "Couldn’t update · previous rate retained"
        }
        return rates.legs[currency] == nil ? "No successful rate yet" : "Available"
    }

    private func refreshButton(busy: Bool, label: String, identifier: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(busy ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise").fixedSize()
        }
        .lfSecondaryAction().disabled(busy || !backgroundUpdates.available)
        .accessibilityLabel(label).accessibilityIdentifier(identifier).help(label)
    }

    private func successTime(_ date: Date) -> some View {
        Text(InvestmentPriceDates.fetchInstant(date))
            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Last successful update \(InvestmentPriceDates.fetchInstant(date))")
    }
}
