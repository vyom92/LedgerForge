import SwiftUI
import AppKit

struct InvestmentListView: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    @ObservedObject var store: InvestmentStore
    @ObservedObject var prices: InvestmentPriceSession
    let availabilityState: ApplicationDataState
    let importStatement: () -> Void
    @State private var selection: String?
    @State private var showsDetails = false
    @AppStorage("investments.table.columns") private var columnCustomization = TableColumnCustomization<InvestmentHolding>()
    @FocusState private var tableFocused: Bool
    @State private var widths: [String: CGFloat] = [:]
    @State private var selectedPortfolio: InvestmentPortfolioSummary?
    @State private var showsHoldingsTable = false

    private var rows: [InvestmentHolding] {
        prices.rows
    }
    private var selected: InvestmentHolding? { store.snapshot.holdings.first { $0.id == selection } }
    private func portfolio(_ holding: InvestmentHolding) -> String {
        prices.portfolioNames[holding.containerID] ?? "Unavailable"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack {
                Text("\(store.snapshot.holdings.count) current holdings")
                    .font(theme.typography.formBody).foregroundStyle(theme.palette.secondaryText)
                Spacer()
                Button("Details", systemImage: "info.circle") { showsDetails.toggle() }
                    .disabled(selected == nil || !showsHoldingsTable).buttonStyle(LFActionButtonStyle(kind: .secondary))
                Button("Import Statement", systemImage: "square.and.arrow.down", action: importStatement)
                    .buttonStyle(LFActionButtonStyle(kind: .primary))
                    .disabled(!availabilityState.permitsMutation)
            }
            if availabilityState == .loading {
                ProgressView("Loading holdings…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if availabilityState == .unavailable || availabilityState == .retainedNonCurrent {
                LFEmptyState(title: "Current holdings unavailable",
                    message: "Restore the database connection to view current investments.", systemImage: "exclamationmark.triangle")
            } else if store.snapshot.holdings.isEmpty {
                LFEmptyState(title: "No current holdings",
                    message: "Import an investment statement to add its closing positions.", systemImage: "chart.pie")
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        InvestmentOverviewView(overview: prices.overview) { portfolio in
                            showsHoldingsTable = false
                            selectedPortfolio = portfolio
                        }
                        .padding(.bottom, showsHoldingsTable || selectedPortfolio != nil ? 0 : holdingsBarHeight)
                    }
                    .disabled(showsHoldingsTable || selectedPortfolio != nil)
                    .accessibilityHidden(showsHoldingsTable || selectedPortfolio != nil)

                    if let selectedPortfolio {
                        portfolioOverlay(prices.overview.portfolios.first { $0.id == selectedPortfolio.id } ?? selectedPortfolio)
                    } else if showsHoldingsTable {
                        holdingsOverlay
                    } else {
                        holdingsBar
                    }
                }
            }
        }
        .padding(theme.spacing.pagePadding)
        .foregroundStyle(theme.palette.primaryText)
        .onChange(of: store.generation) { _, _ in
            selection = nil; showsDetails = false; selectedPortfolio = nil; showsHoldingsTable = false
        }
        .onChange(of: store.snapshot) { _, _ in if selected == nil { selection = nil; showsDetails = false } }
        .onAppear { measurePresentation() }
        .onChange(of: prices.revision) { _, _ in
            measurePresentation()
            if let selectedPortfolio { self.selectedPortfolio = prices.overview.portfolios.first { $0.id == selectedPortfolio.id } }
        }
        .onChange(of: measurementFont) { _, _ in measurePresentation() }
        .onExitCommand {
            guard !showsDetails else { return }
            if selectedPortfolio != nil {
                selectedPortfolio = nil
            } else if showsHoldingsTable {
                showsHoldingsTable = false
            }
        }
        .sheet(isPresented: $showsDetails) {
            if let holding = selected {
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    HStack {
                        VStack(alignment: .leading, spacing: theme.spacing.micro) {
                            Text(holding.displayName).font(theme.typography.formHeading)
                            Text([portfolio(holding), instrumentCodes(holding) ?? "Identifier unavailable"].joined(separator: " · "))
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.palette.secondaryText)
                        }
                        Spacer()
                        Button("Done") { showsDetails = false }.keyboardShortcut(.defaultAction)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                            Text("Position").font(theme.typography.rowTitle)
                            detailLine("Units", holding.units.sourceText)
                            detailLine("Currency", holding.currency)
                            detailLine(holding.sourceDateLabel, InvestmentPriceDates.display(holding.holdingsDate))

                            if let valuation = prices.valuations[holding.id] {
                                Divider().overlay(theme.palette.divider)
                                Text("Current valuation").font(theme.typography.rowTitle)
                                if let quote = valuation.quote {
                                    detailLine("NAV / price", quote.price.sourceText + " " + quote.mapping.currency)
                                    detailLine("Price date", InvestmentPriceDates.display(quote.valuationDay))
                                }
                                if let value = valuation.currentValue { detailLine("Current value", InvestmentArithmetic.displayedMoney(value, currency: holding.currency)) }
                                if let basis = valuation.costBasis, let cost = valuation.supportedCost {
                                    detailLine(basis.rawValue, InvestmentArithmetic.displayedMoney(cost, currency: holding.currency))
                                }
                                if let gain = valuation.gain { detailLine("Gain / loss", InvestmentArithmetic.displayedMoney(gain, currency: holding.currency)) }
                                detailLine("Return", valuation.simpleReturn?.display ?? "—")
                                if let issue = valuation.issue { detailLine("Status", issue) }
                            }

                            DisclosureGroup("Source and exact details") {
                                VStack(alignment: .leading, spacing: theme.spacing.small) {
                                    detailLine("ISIN / Ticker", instrumentCodes(holding) ?? "Not in statement")
                                    detailLine(holding.averageCostLabel ?? "Average cost", cost(holding.averageCost, holding))
                                    detailLine("Source total cost", cost(holding.totalCost, holding))
                                    if let valuation = prices.valuations[holding.id] {
                                        if let value = valuation.currentValue { detailLine("Exact current value", InvestmentArithmetic.text(value) + " " + holding.currency) }
                                        if let cost = valuation.supportedCost { detailLine("Exact supported cost", InvestmentArithmetic.text(cost) + " " + holding.currency) }
                                        if let gain = valuation.gain { detailLine("Exact gain / loss", InvestmentArithmetic.text(gain) + " " + holding.currency) }
                                    }
                                    detailLine("Instrument", holding.instrumentIdentity)
                                    detailLine("Source aliases", holding.sourceAliases.joined(separator: " · "))
                                    detailLine("Source", holding.parserProfile)
                                    if let importID = holding.importSessionID { detailLine("Import", importID) }
                                    if let date = holding.issueDate { detailLine("Issued", date) }
                                    if holding.zioObservationID == nil, let date = holding.valuationDate { detailLine("Statement valuation date", date) }
                                    if let policy = store.snapshot.containers.first(where: { $0.id == holding.containerID })?.zioSource,
                                       let fund = policy.funds.first(where: { $0.code == holding.zioFundCode }) {
                                        detailLine("Source", "Zurich ZIO account")
                                        detailLine("Portal valuation date", policy.valuationDateText)
                                        detailLine("Holdings fetched", policy.fetchedAt.formatted(.iso8601))
                                        detailLine("Source fund code", fund.code)
                                        detailLine("Portal unit price (exact)", fund.price.sourceText + " " + fund.currency)
                                        detailLine("Portal value (exact)", fund.value.sourceText + " " + fund.currency)
                                        detailLine("Portal allocation (exact)", fund.allocation.sourceText + "%")
                                        detailLine("Portal FX rate (exact)", fund.fxRate.sourceText)
                                        if let vested = fund.vestedValue { detailLine("Portal vested value (exact)", vested.sourceText + " " + fund.currency) }
                                        Text("The portal supplies a valuation date, but no separate units-as-of date. Current value above uses the public FE price.")
                                            .foregroundStyle(theme.palette.secondaryText)
                                    }
                                    if let mapping = holding.priceMapping {
                                        detailLine("Price provider", InvestmentPriceRegistry.providerNames[mapping.provider] ?? mapping.provider)
                                        detailLine("Provider lookup", mapping.code)
                                        detailLine("Public instrument", mapping.instrumentReference ?? "Unavailable")
                                        detailLine("Mapping evidence", mapping.evidence ?? "Unavailable")
                                    }
                                    if let quote = prices.valuations[holding.id]?.quote {
                                        detailLine("Price kind", quote.mapping.priceKind ?? "Unavailable")
                                        detailLine("Date basis", quote.dateBasis.label)
                                        if let text = quote.valuationText { detailLine("Provider date / time", text) }
                                        detailLine("Fetched successfully", quote.fetchedAt.formatted(.iso8601))
                                        detailLine("Source qualification", quote.qualification)
                                    }
                                }
                                .padding(.top, theme.spacing.small)
                            }
                            .font(theme.typography.caption)
                        }.textSelection(.enabled)
                    }
                }
                .padding(theme.spacing.panelPadding).frame(width: 560, height: 620)
                .background(theme.palette.inspectorSurface)
            }
        }
    }

    private var holdingsBarHeight: CGFloat {
        theme.typography.compactControlMinimum + theme.spacing.panelPadding * 2
    }

    private var holdingsBar: some View {
        Button {
            selectedPortfolio = nil
            showsHoldingsTable = true
        } label: {
            HStack(spacing: theme.spacing.controlGap) {
                Label("Expand holdings", systemImage: "tablecells")
                    .font(theme.typography.rowTitle)
                Spacer()
                Text("\(rows.count) current holdings")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                Image(systemName: "chevron.up")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
            }
            .padding(theme.spacing.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lfSurface(.subtle)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, theme.spacing.micro)
        .padding(.bottom, theme.spacing.micro)
        .accessibilityHint("Shows the detailed holdings table over the investment overview")
    }

    private func portfolioOverlay(_ portfolio: InvestmentPortfolioSummary) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text("\(portfolio.group.rawValue) holdings").font(theme.typography.formHeading)
                    Text("Fund-level current positions")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Button("Collapse", systemImage: "chevron.down") { selectedPortfolio = nil }
                    .lfSecondaryAction()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityHint("Returns to the investment overview")
            }
            Divider().overlay(theme.palette.divider)
            InvestmentPortfolioDetailView(
                portfolio: portfolio,
                holdings: store.snapshot.holdings,
                containers: store.snapshot.containers,
                portfolioNames: prices.portfolioNames
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(theme.spacing.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .lfSurface(.inspector)
        .padding(theme.spacing.micro)
        .accessibilityElement(children: .contain)
    }

    private var holdingsOverlay: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text("Holdings").font(theme.typography.formHeading)
                    Text("Detailed current positions")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Button("Collapse", systemImage: "chevron.down") { showsHoldingsTable = false }
                    .lfSecondaryAction()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityHint("Returns to the investment overview")
            }
            Divider().overlay(theme.palette.divider)
            table.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(theme.spacing.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .lfSurface(.inspector)
        .padding(theme.spacing.micro)
        .accessibilityElement(children: .contain)
    }

    private func cost(_ number: InvestmentDecimal?, _ holding: InvestmentHolding) -> String {
        guard let number else { return "Unavailable" }
        return number.sourceText + (holding.costCurrency == holding.currency ? "" : " " + (holding.costCurrency ?? ""))
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                Text(title).foregroundStyle(theme.palette.secondaryText)
                Text(value).fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(title).foregroundStyle(theme.palette.secondaryText)
                Text(value).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(theme.typography.secondary)
    }

    private func totalCost(_ holding: InvestmentHolding) -> String {
        InvestmentArithmetic.displayedMoney(holding.totalCost?.value, currency: holding.costCurrency ?? holding.currency)
    }

    private func averageCost(_ holding: InvestmentHolding) -> String {
        InvestmentArithmetic.displayedMoney(holding.averageCost?.value, currency: holding.costCurrency ?? holding.currency)
    }

    private func numericWidth(_ values: [String], heading: String) -> CGFloat {
        let font = theme.typography.nativeFont(.tableMoney, tabularDigits: true)
        return ([heading] + values).map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max()! + 24
    }

    private var measurementFont: String {
        let font = theme.typography.nativeFont(.tableMoney, tabularDigits: true)
        return font.fontName + "|" + String(describing: font.pointSize)
    }

    /// Measure and format once per source/quote/font change, never in the table's redraw path.
    private func measurePresentation() {
        widths = [
            "units": numericWidth(rows.map { $0.units.sourceText }, heading: "Units"),
            "averageCost": numericWidth(rows.map(averageCost), heading: "Avg Cost"),
            "totalCost": numericWidth(rows.map(totalCost), heading: "Total Cost"),
            "price": numericWidth(rows.map { prices.valuations[$0.id]?.quote?.price.sourceText ?? "Unavailable" }, heading: "NAV / Price"),
            "value": numericWidth(Array(prices.valueText.values), heading: "Current value"),
            "gain": numericWidth(Array(prices.gainText.values), heading: "Unrealised gain/loss"),
            "return": numericWidth(Array(prices.returnText.values), heading: "Simple return")]
    }

    private func instrumentName(_ holding: InvestmentHolding) -> String {
        guard let symbol = holding.sourceAliases.first(where: { $0.hasPrefix("symbol:") }).map({ String($0.dropFirst(7)) }),
              holding.displayName.hasPrefix(symbol + " · ") else { return holding.displayName }
        return String(holding.displayName.dropFirst(symbol.count + 3))
    }

    private func instrumentCodes(_ holding: InvestmentHolding) -> String? {
        if let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding), mapping.provider == "fe" { return mapping.code }
        let aliases = [holding.instrumentIdentity] + holding.sourceAliases
        let isin = aliases.first(where: { $0.hasPrefix("isin:") }).map { String($0.dropFirst(5)) }
        let symbol = aliases.first(where: { $0.hasPrefix("symbol:") }).map { String($0.dropFirst(7)) }
        let codes = [isin, symbol].compactMap { $0 }
        return codes.isEmpty ? nil : codes.joined(separator: " · ")
    }

    private var table: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            holdingsTable(at: context.date)
        }
    }

    private func holdingsTable(at now: Date) -> some View {
        Table(rows, selection: $selection, columnCustomization: $columnCustomization) {
            TableColumn("Investment") { holding in
                Text(instrumentName(holding)).lineLimit(2).help(instrumentName(holding))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: theme.typography.tableRowMinimum)
                .padding(.vertical, theme.spacing.micro)
                .overlay(alignment: .leading) {
                    Image(systemName: "checkmark").font(theme.typography.tableSelectionMark)
                        .opacity(holding.id == selection ? 1 : 0).accessibilityHidden(true)
                }
                .background {
                    LFTableRowBackdrop(isSelected: holding.id == selection, isEmphasized: tableFocused && appearsActive)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }.width(min: 230, ideal: 320).alignment(.center).customizationID("investment")
            TableColumn("ISIN / Ticker") { holding in
                Text(instrumentCodes(holding) ?? "Not in statement")
                    .foregroundStyle(theme.palette.secondaryText).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).help(instrumentCodes(holding) ?? "No ISIN or ticker supplied by this statement")
            }.width(min: 185, ideal: 205).alignment(.center).customizationID("identifiers")
            TableColumn("Portfolio/Folio") { holding in
                Text(portfolio(holding)).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).help(portfolio(holding))
            }.width(min: 190, ideal: 240).alignment(.center).customizationID("portfolio")
            TableColumn("Units") { holding in numeric(holding.units.sourceText) }
                .width(min: widths["units"] ?? 100)
                .alignment(.center).customizationID("units")
            TableColumn("Currency") { Text($0.currency).frame(maxWidth: .infinity) }
                .width(min: 78, ideal: 84).alignment(.center).customizationID("currency")
            TableColumn("Avg Cost") { holding in numeric(averageCost(holding)) }
                .width(min: widths["averageCost"] ?? 100)
                .alignment(.center).customizationID("averageCost")
            TableColumn("Total Cost") { holding in numeric(totalCost(holding)) }
                .width(min: widths["totalCost"] ?? 100)
                .alignment(.center).customizationID("totalCost")
            valuationColumns
            TableColumn("NAV / Price date") { holding in valuationDate(prices.valuations[holding.id]?.quote, at: now) }
                .width(min: 145, ideal: 155)
                .alignment(.center).customizationID("valuationDate")
        }
        .font(theme.typography.tableBody)
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .tint(theme.palette.dataSelection)
        .scrollContentBackground(.hidden)
        .background(theme.palette.controlSurface)
        .focused($tableFocused)
        .focusEffectDisabled()
        .overlay(RoundedRectangle(cornerRadius: theme.radius.panel).strokeBorder(theme.palette.tableBorder, lineWidth: 1).allowsHitTesting(false))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel))
    }

    @TableColumnBuilder<InvestmentHolding, Never>
    private var valuationColumns: some TableColumnContent<InvestmentHolding, Never> {
            TableColumn("NAV / Price") { holding in numeric(prices.valuations[holding.id]?.quote?.price.sourceText ?? "Unavailable") }
                .width(min: widths["price"] ?? 115).alignment(.center).customizationID("price")
            TableColumn("Current value") { holding in numeric(prices.valueText[holding.id] ?? "Unavailable") }
                .width(min: widths["value"] ?? 130).alignment(.center).customizationID("currentValue")
            TableColumn("Unrealised gain/loss") { holding in numeric(prices.gainText[holding.id] ?? "Unavailable") }
                .width(min: widths["gain"] ?? 145).alignment(.center).customizationID("unrealisedGain")
            TableColumn("Simple return") { holding in numeric(prices.returnText[holding.id] ?? "Unavailable") }
                .width(min: widths["return"] ?? 115).alignment(.center).customizationID("simpleReturn")
    }

    private func numeric(_ text: String) -> some View {
        Text(text).font(theme.typography.tableMoney).monospacedDigit()
            .fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder private func valuationDate(_ quote: InvestmentQuote?, at now: Date) -> some View {
        if let quote {
            let days = quote.age(at: now)
            let color = ageColor(days)
            Text(InvestmentPriceDates.display(quote.valuationDay))
                .monospacedDigit().fixedSize().foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(LinearGradient(colors: [color.opacity(0.16), color.opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing), in: Capsule())
                .frame(maxWidth: .infinity)
                .help("\(quote.dateBasis.label) · \(days == 0 ? "Today" : "\(days) days old")\(days >= 4 ? " · Stale" : "")")
        } else {
            Text("Unavailable").foregroundStyle(theme.palette.secondaryText).frame(maxWidth: .infinity)
        }
    }

    /// Compare civil dates without inventing a market timestamp or altering source evidence.
    private func civilDay(_ date: StatementDate) -> Int {
        let year = date.year - 1
        let preceding = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let leap = date.year % 4 == 0 && (date.year % 100 != 0 || date.year % 400 == 0)
        return 365 * year + year / 4 - year / 100 + year / 400
            + preceding[date.month - 1] + (leap && date.month > 2 ? 1 : 0) + date.day
    }

    /// Al Dar's visual scale, applied to printed calendar dates: green today,
    /// yellow at one day, gradually red by four days. No rate behavior changes.
    private func ageColor(_ days: Int) -> Color {
        let position = days == 0 ? 0 : min(2, 1 + Double(days - 1) / 3)
        let first = (position <= 1 ? NSColor.systemGreen : NSColor.systemYellow).usingColorSpace(.deviceRGB)!
        let second = (position <= 1 ? NSColor.systemYellow : NSColor.systemRed).usingColorSpace(.deviceRGB)!
        let progress = CGFloat(position <= 1 ? position : position - 1)
        return Color(red: Double(first.redComponent + (second.redComponent - first.redComponent) * progress),
                     green: Double(first.greenComponent + (second.greenComponent - first.greenComponent) * progress),
                     blue: Double(first.blueComponent + (second.blueComponent - first.blueComponent) * progress))
    }
}
