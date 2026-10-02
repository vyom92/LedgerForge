import SwiftUI
import AppKit

func investmentDisplayTitle(_ sourceName: String) -> String {
    sourceName.replacingOccurrences(of: #"\s*\(non[-\s]+demat\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
}

struct InvestmentListView: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    @ObservedObject var store: InvestmentStore
    @ObservedObject var prices: InvestmentPriceSession
    let availabilityState: ApplicationDataState
    let importStatement: () -> Void
    @State private var selection: String?
    @State private var showsCustomizedTable = false
    @State private var fundSelections: [String: String] = [:]
    @State private var sortOrder: [InvestmentHoldingSort] = []
    @FocusState private var focusedHolding: String?
    @AppStorage("investments.table.columns") private var columnCustomization = TableColumnCustomization<InvestmentHolding>()
    @FocusState private var tableFocused: Bool
    @State private var widths: [String: CGFloat] = [:]
    @State private var selectedPortfolio: InvestmentPortfolioSummary?
    @State private var showsHoldingsTable = false

    private var rows: [InvestmentHolding] {
        sortOrder.isEmpty ? prices.rows : prices.rows.sorted(using: sortOrder)
    }
    private var selected: InvestmentHolding? { store.snapshot.holdings.first { $0.id == selection } }
    private func portfolio(_ holding: InvestmentHolding) -> String {
        prices.portfolioNames[holding.containerID] ?? "Unavailable"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: theme.spacing.micro) {
                    Text("Investments").font(theme.typography.pageTitle)
                    Text(selectedPortfolio.map { "\($0.group.rawValue) holdings · \($0.scope.holdingCount) positions" }
                     ?? "\(store.snapshot.holdings.count) current holdings · \(showsHoldingsTable ? "All holdings" : "Portfolio overview")")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
                Spacer(minLength: theme.spacing.small)
                if showsHoldingsTable && selectedPortfolio == nil {
                    Button(showsCustomizedTable ? "Compact rows" : "Table columns", systemImage: "tablecells") {
                        showsCustomizedTable.toggle()
                    }.lfSecondaryAction()
                        .help("Open the table with your saved columns")
                }
                Button(showsHoldingsTable || selectedPortfolio != nil ? "Collapse holdings" : "Expand holdings",
                       systemImage: showsHoldingsTable || selectedPortfolio != nil ? "chevron.up" : "list.bullet") {
                    if selectedPortfolio != nil || showsHoldingsTable { selectedPortfolio = nil; showsHoldingsTable = false }
                    else { showsHoldingsTable = true }
                }.lfSecondaryAction()
            }
            if availabilityState == .loading {
                ProgressView("Loading holdings…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if availabilityState == .unavailable || availabilityState == .retainedNonCurrent {
                LFEmptyState(title: "Current holdings unavailable",
                    message: "Restore the database connection to view current investments.", systemImage: "exclamationmark.triangle")
            } else if store.snapshot.holdings.isEmpty {
                LFEmptyState(title: "No current holdings",
                    message: "Import an investment statement to add its closing positions.", systemImage: "chart.pie")
            } else if let selectedPortfolio {
                InvestmentPortfolioDetailView(
                    portfolio: prices.overview.portfolios.first { $0.id == selectedPortfolio.id } ?? selectedPortfolio,
                    overview: prices.overview, holdings: store.snapshot.holdings,
                    containers: store.snapshot.containers, portfolioNames: prices.portfolioNames,
                    valuations: prices.valuations,
                    selection: Binding(get: { fundSelections[selectedPortfolio.id] },
                                       set: { fundSelections[selectedPortfolio.id] = $0 }))
            } else if showsHoldingsTable {
                if showsCustomizedTable {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        HStack {
                            Text("Drag column headings to reorder; use the heading menu to show columns.")
                                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                            Spacer()
                            if selected != nil {
                                Button("Show selected holding details") { showsCustomizedTable = false }.buttonStyle(.link)
                            }
                        }
                        table
                    }
                } else { compactHoldings }
            } else {
                GeometryReader { viewport in
                    ScrollView {
                        InvestmentOverviewView(overview: prices.overview, availableWidth: viewport.size.width - theme.spacing.micro) { selectedPortfolio = $0 }
                            .padding(.trailing, theme.spacing.micro)
                    }
                }
            }
        }
        .padding(theme.spacing.pagePadding)
        .foregroundStyle(theme.palette.primaryText)
        .onChange(of: store.generation) { _, _ in
            selection = nil; selectedPortfolio = nil; showsHoldingsTable = false; fundSelections = [:]
        }
        .onChange(of: store.snapshot) { _, _ in if selected == nil { selection = nil } }
        .onAppear { measurePresentation() }
        .onChange(of: prices.revision) { _, _ in
            measurePresentation()
            sortOrder = sortOrder.map { comparator($0.field, order: $0.order) }
            if let selectedPortfolio { self.selectedPortfolio = prices.overview.portfolios.first { $0.id == selectedPortfolio.id } }
        }
        .onChange(of: measurementFont) { _, _ in measurePresentation() }
        .onExitCommand {
            if selectedPortfolio != nil { selectedPortfolio = nil }
            else if showsCustomizedTable { showsCustomizedTable = false }
            else if selection != nil { selection = nil }
            else { showsHoldingsTable = false }
        }
    }

    private var compactHoldings: some View {
        GeometryReader { viewport in
            let wide = viewport.size.width >= 1080
            let showsDate = viewport.size.width >= 850
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Text("Values in each investment’s currency")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: theme.spacing.sectionGap) {
                                sortHeading("Investment", field: .investment).frame(maxWidth: .infinity, alignment: .leading)
                                if wide { sortHeading("Portfolio", field: .portfolio).frame(width: 175, alignment: .leading) }
                                sortHeading("Units", field: .units).frame(width: compactUnitsWidth, alignment: .trailing)
                                if showsDate { sortHeading("NAV / price date", field: .date).frame(width: 150, alignment: .leading) }
                                sortHeading("Current value", field: .value).frame(width: compactValueWidth, alignment: .trailing)
                            }.padding(.horizontal, theme.spacing.controlGap).padding(.vertical, theme.spacing.controlGap)
                            Divider()
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(rows) { holding in
                                    compactHoldingRow(holding, wide: wide, showsDate: showsDate)
                                        .id(holding.id)
                                        .onKeyPress(.downArrow) { moveHolding(from: holding.id, by: 1, proxy: proxy); return .handled }
                                        .onKeyPress(.upArrow) { moveHolding(from: holding.id, by: -1, proxy: proxy); return .handled }
                                    if selection == holding.id {
                                        InvestmentHoldingInlineDetails(holding: holding,
                                            valuation: prices.valuations[holding.id],
                                            container: store.snapshot.containers.first { $0.id == holding.containerID },
                                            portfolioName: portfolio(holding))
                                            .padding(theme.spacing.controlGap).lfSurface(.subtle)
                                            .padding(.horizontal, theme.spacing.small)
                                            .padding(.bottom, theme.spacing.controlGap)
                                    }
                                    Divider()
                                }
                            }
                        }.padding(theme.spacing.small)
                    }
                    .lfSurface()
                    .onAppear { if let selection { proxy.scrollTo(selection, anchor: .center) } }
                }
            }
        }
    }

    private var compactUnitsWidth: CGFloat {
        max(100, investmentColumnWidth(rows.map { $0.units.sourceText }, role: .body))
    }
    private var compactValueWidth: CGFloat {
        max(150, investmentColumnWidth(Array(prices.valueText.values), role: .body))
    }
    private func investmentColumnWidth(_ values: [String], role: LFFontRole) -> CGFloat {
        let font = theme.typography.nativeFont(role, tabularDigits: true)
        return ceil(values.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0) + 8
    }

    private func compactHoldingRow(_ holding: InvestmentHolding, wide: Bool, showsDate: Bool) -> some View {
        Button {
            selection = selection == holding.id ? nil : holding.id
            focusedHolding = holding.id
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.sectionGap) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.small) {
                    Image(systemName: selection == holding.id ? "chevron.down" : "chevron.right")
                        .font(theme.typography.caption).frame(width: 14).foregroundStyle(theme.palette.secondaryText)
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(instrumentName(holding)).font(theme.typography.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(wide ? (instrumentCodes(holding) ?? holding.currency) : portfolio(holding))
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if wide {
                    Text(portfolio(holding)).font(theme.typography.secondary)
                        .foregroundStyle(theme.palette.secondaryText).frame(width: 175, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(holding.units.sourceText).font(theme.typography.body).monospacedDigit()
                    .fixedSize().frame(width: compactUnitsWidth, alignment: .trailing)
                if showsDate {
                    Text(prices.valuations[holding.id]?.quote.map { InvestmentPriceDates.display($0.valuationDay) } ?? "Unavailable")
                        .font(theme.typography.secondary).monospacedDigit()
                        .foregroundStyle(prices.valuations[holding.id]?.quote.map { ageColor($0.freshnessAge(at: .now)) } ?? theme.palette.secondaryText)
                        .frame(width: 150, alignment: .leading)
                }
                Text(prices.valueText[holding.id] ?? "Unavailable").font(theme.typography.body).monospacedDigit()
                    .fixedSize().frame(width: compactValueWidth, alignment: .trailing)
            }
            .padding(.horizontal, theme.spacing.controlGap).padding(.vertical, theme.spacing.sectionGap)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selection == holding.id ? theme.palette.dataSelection : Color.clear,
                        in: RoundedRectangle(cornerRadius: theme.radius.control))
            .overlay(alignment: .leading) {
                if selection == holding.id { RoundedRectangle(cornerRadius: 2).fill(theme.interaction.focusRing).frame(width: 3).padding(.vertical, 8) }
            }
            .contentShape(Rectangle())
        }.buttonStyle(LFPlainActionStyle()).focusable().focused($focusedHolding, equals: holding.id)
            .accessibilityLabel(instrumentName(holding) + ", " + portfolio(holding) + ", " + holding.units.sourceText + " units, " + (prices.valueText[holding.id] ?? "Value unavailable"))
            .accessibilityValue(selection == holding.id ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("investments.holding." + holding.id)
    }

    private func moveHolding(from id: String, by step: Int, proxy: ScrollViewProxy) {
        guard let index = rows.firstIndex(where: { $0.id == id }), rows.indices.contains(index + step) else { return }
        let next = rows[index + step].id
        selection = next; focusedHolding = next
        proxy.scrollTo(next, anchor: .center)
    }

    private func sortHeading(_ title: String, field: InvestmentHoldingSort.Field) -> some View {
        Button {
            let order: SortOrder = sortOrder.first?.field == field && sortOrder.first?.order == .forward ? .reverse : .forward
            sortOrder = [comparator(field, order: order)]
        } label: {
            HStack(spacing: theme.spacing.micro) {
                Text(title)
                if sortOrder.first?.field == field {
                    Image(systemName: sortOrder.first?.order == .forward ? "chevron.up" : "chevron.down").font(theme.typography.caption)
                }
            }
        }.buttonStyle(.plain).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            .accessibilityLabel("Sort by " + title)
    }

    private func comparator(_ field: InvestmentHoldingSort.Field, order: SortOrder = .forward) -> InvestmentHoldingSort {
        InvestmentHoldingSort(field: field, order: order, facts: Dictionary(uniqueKeysWithValues: prices.rows.map { holding in
            (holding.id, .init(name: instrumentName(holding), portfolio: portfolio(holding), date: prices.valuations[holding.id]?.quote?.valuationDay,
                               value: prices.valuations[holding.id]?.currentValue))
        }))
    }

    private func totalCost(_ holding: InvestmentHolding) -> String {
        InvestmentArithmetic.displayedMoney(holding.totalCost?.value, currency: holding.costCurrency ?? holding.currency)
    }

    private func averageCost(_ holding: InvestmentHolding) -> String {
        holding.averageCost.map { MoneyFormatting.unitPrice($0.sourceText, currency: holding.costCurrency ?? holding.currency) } ?? "Unavailable"
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
              holding.displayName.hasPrefix(symbol + " · ") else { return investmentDisplayTitle(holding.displayName) }
        return investmentDisplayTitle(String(holding.displayName.dropFirst(symbol.count + 3)))
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
        Table(rows, selection: $selection, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            TableColumn("Investment", sortUsing: comparator(.investment)) { holding in
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
            TableColumn("Portfolio/Folio", sortUsing: comparator(.portfolio)) { holding in
                Text(portfolio(holding)).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).help(portfolio(holding))
            }.width(min: 190, ideal: 240).alignment(.center).customizationID("portfolio")
            TableColumn("Units", sortUsing: comparator(.units)) { holding in numeric(holding.units.sourceText) }
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
            TableColumn("NAV / Price date", sortUsing: comparator(.date)) { holding in valuationDate(prices.valuations[holding.id]?.quote, at: now) }
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

    @TableColumnBuilder<InvestmentHolding, InvestmentHoldingSort>
    private var valuationColumns: some TableColumnContent<InvestmentHolding, InvestmentHoldingSort> {
            TableColumn("NAV / Price") { holding in numeric(prices.valuations[holding.id]?.quote?.price.sourceText ?? "Unavailable") }
                .width(min: widths["price"] ?? 115).alignment(.center).customizationID("price")
            TableColumn("Current value", sortUsing: comparator(.value)) { holding in numeric(prices.valueText[holding.id] ?? "Unavailable") }
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
            let freshness = quote.freshnessAge(at: now)
            let color = ageColor(freshness)
            Text(InvestmentPriceDates.display(quote.valuationDay))
                .monospacedDigit().fixedSize().foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(LinearGradient(colors: [color.opacity(0.16), color.opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing), in: Capsule())
                .frame(maxWidth: .infinity)
                .help("\(quote.dateBasis.label) · \(days == 0 ? "Today" : "\(days) days old")\(freshness >= 4 ? " · Stale" : "")")
        } else {
            Text("Unavailable").foregroundStyle(theme.palette.secondaryText).frame(maxWidth: .infinity)
        }
    }

    /// Al Dar's visual scale, applied to printed calendar dates: green today,
    /// yellow at one day, gradually red by four days. No rate behavior changes.
    private func ageColor(_ days: Int) -> Color {
        FreshnessTint.color(position: WeekdayFreshness.colorPosition(days: Double(days)))
    }
}


/// View-local ordering; values are read from the accepted presentation snapshot.
/// Sorting native amounts groups by currency before comparing values.
nonisolated private struct InvestmentHoldingSort: SortComparator {
    enum Field: Hashable, Sendable { case investment, portfolio, units, date, value }
    struct Fact: Hashable, Sendable { let name: String; let portfolio: String; let date: String?; let value: Decimal? }
    var field: Field
    var order: SortOrder = .forward
    var facts: [String: Fact] = [:]

    func compare(_ lhs: InvestmentHolding, _ rhs: InvestmentHolding) -> ComparisonResult {
        let result: ComparisonResult
        switch field {
        case .investment: result = (facts[lhs.id]?.name ?? lhs.displayName).localizedStandardCompare(facts[rhs.id]?.name ?? rhs.displayName)
        case .portfolio: result = (facts[lhs.id]?.portfolio ?? "").localizedStandardCompare(facts[rhs.id]?.portfolio ?? "")
        case .units: result = ordered(lhs.units.value, rhs.units.value)
        case .date:
            if facts[lhs.id]?.date == nil || facts[rhs.id]?.date == nil {
                return missing(facts[lhs.id]?.date, facts[rhs.id]?.date)
            }
            result = ordered(facts[lhs.id]!.date!, facts[rhs.id]!.date!)
        case .value:
            if facts[lhs.id]?.value == nil || facts[rhs.id]?.value == nil {
                return missing(facts[lhs.id]?.value, facts[rhs.id]?.value)
            }
            result = lhs.currency == rhs.currency ? ordered(facts[lhs.id]!.value!, facts[rhs.id]!.value!)
                : lhs.currency.localizedStandardCompare(rhs.currency)
        }
        return order == .forward ? result : result == .orderedAscending ? .orderedDescending : result == .orderedDescending ? .orderedAscending : .orderedSame
    }
    private func ordered<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
        a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
    }
    private func missing<T>(_ a: T?, _ b: T?) -> ComparisonResult {
        a == nil ? (b == nil ? .orderedSame : .orderedDescending) : .orderedAscending
    }
}

struct InvestmentHoldingInlineDetails: View {
    @Environment(\.lfTheme) private var theme
    let holding: InvestmentHolding
    let valuation: InvestmentValuation?
    let container: InvestmentContainer?
    let portfolioName: String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("Price & statement details").font(theme.typography.rowTitle)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), alignment: .topLeading)], alignment: .leading, spacing: theme.spacing.controlGap) {
                tile("Identifier", instrumentCodes(holding) ?? "Not in statement")
                tile("Portfolio / Folio", portfolioName)
                tile(holding.averageCostLabel ?? "Average cost", cost(holding.averageCost, holding))
                tile("Source total cost", cost(holding.totalCost, holding))
                tile("Units", holding.units.sourceText)
                tile("NAV / price", valuation?.quote.map { MoneyFormatting.unitPrice($0.price.sourceText, currency: $0.mapping.currency) } ?? "Unavailable")
                tile("NAV / price date", valuation?.quote.map { InvestmentPriceDates.display($0.valuationDay) } ?? "Unavailable")
                tile(holding.sourceDateLabel, InvestmentPriceDates.display(holding.holdingsDate))
                tile("Current value", InvestmentArithmetic.displayedMoney(valuation?.currentValue, currency: holding.currency))
                if let basis = valuation?.costBasis {
                    tile(basis.rawValue, InvestmentArithmetic.displayedMoney(valuation?.supportedCost, currency: holding.currency))
                }
                tile("Gain / loss", InvestmentArithmetic.displayedMoney(valuation?.gain, currency: holding.currency))
                tile("Return", valuation?.simpleReturn?.display ?? "Unavailable")
            }
            if let issue = valuation?.issue {
                Text(issue).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    detailLine("Source fund name", holding.displayName)
                    detailLine("ISIN / Ticker", instrumentCodes(holding) ?? "Not in statement")
                    detailLine(holding.averageCostLabel ?? "Average cost", cost(holding.averageCost, holding))
                    detailLine("Source total cost", cost(holding.totalCost, holding))
                    if let valuation = valuation {
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
                    if let policy = container?.zioSource,
                       let fund = policy.funds.first(where: { $0.code == holding.zioFundCode }) {
                        detailLine("Source", "Zurich ZIO account")
                        detailLine("Portal valuation date", policy.valuationDateText)
                        detailLine("Holdings fetched", AppDateDisplay.timestamp(policy.fetchedAt, zone: TimeZone(secondsFromGMT: 0)!))
                        detailLine("Source fund code", fund.code)
                        detailLine("Portal unit price (exact)", fund.price.sourceText + " " + fund.currency)
                        detailLine("Portal value (exact)", fund.value.sourceText + " " + fund.currency)
                        detailLine("Portal allocation (exact)", fund.allocation.sourceText + "%")
                        detailLine("Portal FX rate (exact)", fund.fxRate.sourceText)
                        if let vested = fund.vestedValue { detailLine("Portal vested value (exact)", vested.sourceText + " " + fund.currency) }
                        Text("The portal supplies a valuation date, but no separate units-as-of date. Current value above uses the public FE price.")
                            .foregroundStyle(theme.palette.secondaryText)
                    }
                    if let mapping = valuation?.quote?.mapping ?? holding.priceMapping {
                        detailLine("Price provider", InvestmentPriceRegistry.providerNames[mapping.provider] ?? mapping.provider)
                        detailLine("Provider lookup", mapping.code)
                        detailLine("Public instrument", mapping.instrumentReference ?? "Unavailable")
                        detailLine("Mapping evidence", mapping.evidence ?? "Unavailable")
                    }
                    if let quote = valuation?.quote {
                        detailLine("Price kind", quote.mapping.priceKind ?? "Unavailable")
                        detailLine("Date basis", quote.dateBasis.label)
                        if let text = quote.valuationText { detailLine("Provider date / time", text) }
                        detailLine("Fetched successfully", AppDateDisplay.timestamp(quote.fetchedAt, zone: TimeZone(secondsFromGMT: 0)!))
                        detailLine("Source qualification", quote.qualification)
                    }
                }.padding(.top, theme.spacing.small)
            } label: {
                Text("Source and exact details").textSelection(.disabled)
            }
                .font(theme.typography.secondary)
                .accessibilityIdentifier("investments.sourceDetails.\(holding.id)")
        }.textSelection(.enabled)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            Text(value).font(theme.typography.body).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func detailLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.micro) {
            Text(title).foregroundStyle(theme.palette.secondaryText)
            Text(value).fixedSize(horizontal: false, vertical: true)
        }.font(theme.typography.secondary)
    }
    private func cost(_ number: InvestmentDecimal?, _ holding: InvestmentHolding) -> String {
        guard let number else { return "Unavailable" }
        return MoneyFormatting.unitPrice(number.sourceText, currency: holding.costCurrency ?? holding.currency)
    }
    private func instrumentCodes(_ holding: InvestmentHolding) -> String? {
        if let mapping = InvestmentPriceRegistry.confirmedMapping(for: holding), mapping.provider == "fe" { return mapping.code }
        let aliases = [holding.instrumentIdentity] + holding.sourceAliases
        let isin = aliases.first(where: { $0.hasPrefix("isin:") }).map { String($0.dropFirst(5)) }
        let symbol = aliases.first(where: { $0.hasPrefix("symbol:") }).map { String($0.dropFirst(7)) }
        let codes = [isin, symbol].compactMap { $0 }
        return codes.isEmpty ? nil : codes.joined(separator: " · ")
    }
}
