import SwiftUI
import AppKit

struct InvestmentListView: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    @ObservedObject var store: InvestmentStore
    let availabilityState: ApplicationDataState
    let importStatement: () -> Void
    @State private var selection: String?
    @State private var showsDetails = false
    @AppStorage("investments.table.columns") private var columnCustomization = TableColumnCustomization<InvestmentHolding>()
    @FocusState private var tableFocused: Bool

    private var rows: [InvestmentHolding] {
        store.snapshot.holdings.sorted {
            let left = portfolio($0), right = portfolio($1)
            if left != right { return left.localizedStandardCompare(right) == .orderedAscending }
            if $0.sourceOrdinal != $1.sourceOrdinal { return $0.sourceOrdinal < $1.sourceOrdinal }
            return $0.id < $1.id
        }
    }
    private var selected: InvestmentHolding? { store.snapshot.holdings.first { $0.id == selection } }
    private func portfolio(_ holding: InvestmentHolding) -> String {
        guard let container = store.snapshot.containers.first(where: { $0.id == holding.containerID }) else { return "Unavailable" }
        let name = container.institution == "Zurich ISP"
            ? container.displayName.replacingOccurrences(of: "Zurich · ", with: "ISP · ") : container.displayName
        return name.contains(container.identity) ? name : name + " · " + container.identity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack {
                Text("\(store.snapshot.holdings.count) current holdings")
                    .font(theme.typography.formBody).foregroundStyle(theme.palette.secondaryText)
                Spacer()
                Button("Details", systemImage: "info.circle") { showsDetails.toggle() }
                    .disabled(selected == nil).buttonStyle(LFActionButtonStyle(kind: .secondary))
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
                table
            }
        }
        .padding(theme.spacing.pagePadding)
        .foregroundStyle(theme.palette.primaryText)
        .onChange(of: store.generation) { _, _ in selection = nil; showsDetails = false }
        .onChange(of: store.snapshot) { _, _ in if selected == nil { selection = nil; showsDetails = false } }
        .sheet(isPresented: $showsDetails) {
            if let holding = selected {
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                    HStack {
                        Text("Holding details").font(theme.typography.formHeading)
                        Spacer()
                        Button("Done") { showsDetails = false }.keyboardShortcut(.defaultAction)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            LFInfoRow(title: "Investment", value: holding.displayName)
                            LFInfoRow(title: "Portfolio/Folio", value: portfolio(holding))
                            LFInfoRow(title: "Units", value: holding.units.sourceText)
                            LFInfoRow(title: "Currency", value: holding.currency)
                            LFInfoRow(title: holding.averageCostLabel ?? "Average cost", value: cost(holding.averageCost, holding))
                            LFInfoRow(title: holding.totalCostLabel ?? "Total cost", value: cost(holding.totalCost, holding))
                            LFInfoRow(title: "Holdings as of", value: holding.holdingsDate)
                            LFInfoRow(title: "Instrument", value: holding.instrumentIdentity)
                            LFInfoRow(title: "Source aliases", value: holding.sourceAliases.joined(separator: " · "))
                            LFInfoRow(title: "Source", value: holding.parserProfile)
                            LFInfoRow(title: "Import", value: holding.importSessionID)
                            if let date = holding.issueDate { LFInfoRow(title: "Issued", value: date) }
                            if let date = holding.valuationDate { LFInfoRow(title: "Statement valuation date", value: date) }
                        }.textSelection(.enabled)
                    }
                }
                .padding(theme.spacing.panelPadding).frame(width: 480, height: 520)
                .background(theme.palette.canvas)
            }
        }
    }

    private func cost(_ number: InvestmentDecimal?, _ holding: InvestmentHolding) -> String {
        guard let number else { return "Unavailable" }
        return number.sourceText + (holding.costCurrency == holding.currency ? "" : " " + (holding.costCurrency ?? ""))
    }

    private func numericWidth(_ values: [String], heading: String) -> CGFloat {
        let font = theme.typography.nativeFont(.tableMoney, tabularDigits: true)
        return ([heading] + values).map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max()! + 24
    }

    private func instrumentName(_ holding: InvestmentHolding) -> String {
        guard let symbol = holding.sourceAliases.first(where: { $0.hasPrefix("symbol:") }).map({ String($0.dropFirst(7)) }),
              holding.displayName.hasPrefix(symbol + " · ") else { return holding.displayName }
        return String(holding.displayName.dropFirst(symbol.count + 3))
    }

    private func instrumentCodes(_ holding: InvestmentHolding) -> String? {
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
                    .foregroundStyle(theme.palette.secondaryText).lineLimit(1)
                    .frame(maxWidth: .infinity).help(instrumentCodes(holding) ?? "No ISIN or ticker supplied by this statement")
            }.width(min: 185, ideal: 205).alignment(.center).customizationID("identifiers")
            TableColumn("Portfolio/Folio") { holding in
                Text(portfolio(holding)).lineLimit(2).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).help(portfolio(holding))
            }.width(min: 190, ideal: 240).alignment(.center).customizationID("portfolio")
            TableColumn("Units") { holding in numeric(holding.units.sourceText) }
                .width(min: numericWidth(store.snapshot.holdings.map { $0.units.sourceText }, heading: "Units"))
                .alignment(.center).customizationID("units")
            TableColumn("Currency") { Text($0.currency).frame(maxWidth: .infinity) }
                .width(min: 78, ideal: 84).alignment(.center).customizationID("currency")
            TableColumn("Avg Cost") { holding in numeric(cost(holding.averageCost, holding)) }
                .width(min: numericWidth(store.snapshot.holdings.map { cost($0.averageCost, $0) }, heading: "Avg Cost"))
                .alignment(.center).customizationID("averageCost")
            TableColumn("Total Cost") { holding in numeric(cost(holding.totalCost, holding)) }
                .width(min: numericWidth(store.snapshot.holdings.map { cost($0.totalCost, $0) }, heading: "Total Cost"))
                .alignment(.center).customizationID("totalCost")
            TableColumn("NAV / Price date") { holding in valuationDate(holding.valuationDate, at: now) }
                .width(min: numericWidth([], heading: "NAV / Price date"), ideal: 145)
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

    private func numeric(_ text: String) -> some View {
        Text(text).font(theme.typography.tableMoney).monospacedDigit()
            .fixedSize(horizontal: true, vertical: false).frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder private func valuationDate(_ canonical: String?, at now: Date) -> some View {
        if let canonical, let date = try? StatementDate(canonical: canonical) {
            let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: now)
            let today = try? StatementDate(year: components.year!, month: components.month!, day: components.day!)
            let days = today.map { max(0, civilDay($0) - civilDay(date)) } ?? 0
            let color = ageColor(days)
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            Text(String(format: "%02d %@ %04d", date.day, months[date.month - 1], date.year))
                .monospacedDigit().fixedSize().foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(LinearGradient(colors: [color.opacity(0.16), color.opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing), in: Capsule())
                .frame(maxWidth: .infinity)
                .help("Statement NAV / price date · \(days == 0 ? "Today" : "\(days) calendar days old")")
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
