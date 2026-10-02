import SwiftUI
import Charts

nonisolated enum PeriodOverviewRange: String, CaseIterable {
    case one = "1M", three = "3M", six = "6M", custom = "Custom"

    func dates(ending today: StatementDate) -> TransactionPresentationStatementDateRange? {
        let months: Int
        switch self {
        case .one: months = 1
        case .three: months = 3
        case .six: months = 6
        case .custom: return nil
        }
        guard let instant = FinancialCalendar.instant(today),
              let start = FinancialCalendar.calendar.date(byAdding: .month, value: -months, to: instant),
              let civil = FinancialCalendar.statement(start) else { return nil }
        return .init(start: civil, end: today)
    }

    static func today(now: Date = Date(), timeZone: TimeZone = .current) -> StatementDate? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return try? StatementDate(year: year, month: month, day: day)
    }
}

nonisolated struct PeriodOverviewDay: Identifiable {
    let date: StatementDate
    let totals: TransactionPresentationTotals
    var id: StatementDate { date }

    static func observed(in rows: [TransactionPresentationRow]) -> [Self] {
        let dated = rows.filter { $0.sourceCivilDate != nil }
        return Dictionary(grouping: dated, by: { $0.sourceCivilDate! })
            .map { Self(date: $0.key, totals: TransactionPresentationEngine.totals(for: $0.value)) }
            .sorted { $0.date < $1.date }
    }
}

struct PeriodOverviewControls: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var model: TransactionListViewModel
    let retainedCriteria: String
    @State private var chosenRange: PeriodOverviewRange?
    @State private var customStart = ""
    @State private var customEnd = ""
    @State private var customPresented = false
    @State private var dateError: String?

    private var accounts: [Account] {
        model.presentationAccounts.filter { $0.repositoryAccountId != nil }
            .sorted { $0.preferredDisplayName.localizedStandardCompare($1.preferredDisplayName) == .orderedAscending }
    }
    private var accountTitle: String {
        let filter = model.presentationFilter
        if filter.excludesAllAccounts { return "No accounts selected" }
        if filter.accountIDs.isEmpty { return "Current accounts" }
        if filter.accountIDs.count == 1,
           let account = accounts.first(where: { filter.accountIDs.contains($0.repositoryAccountId!) }) {
            return account.preferredDisplayName
        }
        return "\(filter.accountIDs.count) accounts selected"
    }
    private var dateTitle: String {
        let filter = model.presentationFilter
        let dates = filter.statementDateRange.map {
            "\($0.start?.presentation ?? "First recorded date") – \($0.end?.presentation ?? "Last recorded date")"
        }
        let months = filter.statementMonths.sorted().map(\.canonical).joined(separator: ", ")
        if let dates { return months.isEmpty ? dates : dates + " · Statement months: " + months }
        return months.isEmpty ? "All recorded dates" : "Statement months: " + months
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { dateControls; accountControl }
                VStack(alignment: .leading, spacing: 14) { dateControls; accountControl }
            }
            if !retainedCriteria.isEmpty {
                Text(retainedCriteria).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dateControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Period").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                ForEach(PeriodOverviewRange.allCases, id: \.self) { choice in
                    Button(choice.rawValue) {
                        if choice == .custom {
                            customStart = model.presentationFilter.statementDateRange?.start?.canonical ?? ""
                            customEnd = model.presentationFilter.statementDateRange?.end?.canonical ?? ""
                            dateError = nil
                            customPresented = true
                        } else if let today = PeriodOverviewRange.today(), let range = choice.dates(ending: today) {
                            apply(range, choice: choice)
                        }
                    }
                    .buttonStyle(LFActionButtonStyle(kind: chosenRange == choice ? .primary : .secondary))
                    .accessibilityAddTraits(chosenRange == choice ? .isSelected : [])
                    .accessibilityIdentifier("periodOverview.range.\(choice.rawValue)")
                }
            }
            Text(dateTitle).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .popover(isPresented: $customPresented) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Custom period").font(theme.typography.sectionTitle)
                TextField("From YYYY-MM-DD", text: $customStart).accessibilityLabel("Period start date")
                TextField("To YYYY-MM-DD", text: $customEnd).accessibilityLabel("Period end date")
                if let dateError { Text(dateError).foregroundStyle(LFTheme.warning) }
                HStack {
                    Button("Cancel") { customPresented = false }.lfSecondaryAction()
                    Spacer()
                    Button("Apply dates") {
                        guard let start = try? StatementDate(canonical: customStart),
                              let end = try? StatementDate(canonical: customEnd), start <= end else {
                            dateError = "Enter both dates as YYYY-MM-DD, with the start on or before the end."
                            return
                        }
                        apply(.init(start: start, end: end), choice: .custom)
                        customPresented = false
                    }.lfSecondaryAction()
                }
            }.textFieldStyle(.roundedBorder).padding(20).frame(width: 360)
        }
    }

    private var accountControl: some View {
        let scope = AccountPresentationScope(selectedAccountIDs: model.presentationFilter.accountIDs,
            historyOnlyAccountIDs: AccountPresentationScope.historyOnlyIDs(in: accounts),
            excludesAllAccounts: model.presentationFilter.excludesAllAccounts)
        return VStack(alignment: .leading, spacing: 8) {
            LFAccountMenu(title: accountTitle, allTitle: "Current accounts", options: accounts.map { account in
                let id = account.repositoryAccountId!
                return .init(id: id, title: account.preferredDisplayName, detail: account.selectionContext,
                    selected: scope.includes(id))
            }) { id in
                if let id {
                    var filter = model.presentationFilter
                    var selection = filter.excludesAllAccounts ? [] : filter.accountIDs.isEmpty
                        ? Set(accounts.filter { scope.includes($0.repositoryAccountId) }.compactMap(\.repositoryAccountId)) : filter.accountIDs
                    if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
                    filter.accountIDs = selection
                    filter.excludesAllAccounts = selection.isEmpty
                    model.presentationFilter = filter
                } else {
                    model.presentationFilter.accountIDs = []
                    model.presentationFilter.excludesAllAccounts = false
                }
            }
            .fixedSize().accessibilityLabel("Include accounts")
            .accessibilityIdentifier("periodOverview.accounts")
            Text("Include accounts").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func apply(_ range: TransactionPresentationStatementDateRange, choice: PeriodOverviewRange) {
        var filter = model.presentationFilter
        filter.statementDateRange = range
        filter.statementMonths = []
        model.presentationFilter = filter
        chosenRange = choice
    }
}

struct PeriodOverviewActivityChart: View {
    @Environment(\.lfTheme) private var theme
    let rows: [TransactionPresentationRow]
    let range: TransactionPresentationStatementDateRange?
    var chartHeight: CGFloat = 145
    @State private var chosenSeries: String?
    @State private var hoverDate: Date?

    private struct Series: Identifiable {
        let currency: CurrencyCode
        let domain: TransactionPresentationDomain
        var id: String { currency.code + "-" + domain.rawValue }
        var title: String { currency.code + (domain == .bank ? " · Bank movements" : " · Card liability") }
    }
    private var days: [PeriodOverviewDay] { PeriodOverviewDay.observed(in: rows) }
    private var series: [Series] {
        let keys = Set(days.flatMap { $0.totals.partitions.keys })
        let ids = Set(keys.filter { $0.domain != .unknown }.map { $0.currency.code + "-" + $0.domain.rawValue })
        return ids.sorted().compactMap { id in
            guard let key = keys.first(where: { $0.currency.code + "-" + $0.domain.rawValue == id }) else { return nil }
            return Series(currency: key.currency, domain: key.domain)
        }
    }
    private var current: Series? { series.first(where: { $0.id == chosenSeries }) ?? series.first }
    private func effects(_ series: Series) -> [TransactionPresentationEffect] {
        series.domain == .bank ? [.credit, .debit] : [.decreasesAmountOwed, .increasesAmountOwed]
    }
    private func title(_ effect: TransactionPresentationEffect) -> String {
        switch effect {
        case .credit: "Inflow"
        case .debit: "Outflow"
        case .increasesAmountOwed: "Increase owed"
        case .decreasesAmountOwed: "Decrease owed"
        case .unknown: "Unavailable"
        }
    }
    private func domain(_ days: [PeriodOverviewDay]) -> ClosedRange<Date>? {
        guard let first = range?.start ?? days.first?.date,
              let last = range?.end ?? days.last?.date,
              let afterLast = FinancialCalendar.addDays(1, to: last),
              let start = FinancialCalendar.instant(first),
              let end = FinancialCalendar.instant(afterLast) else { return nil }
        return start...end
    }

    var body: some View {
        let observed = days
        LFPanel(contentSpacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Activity over time").font(theme.typography.sectionTitle)
                    Spacer()
                    if !series.isEmpty { seriesPicker }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity over time").font(theme.typography.sectionTitle)
                    if !series.isEmpty { seriesPicker }
                }
            }
            if let selected = current, let bounds = domain(observed) {
                chart(observed, selected: selected, bounds: bounds)
                hoverReadout(observed, selected: selected)
            } else {
                Text("No dated amounts to chart in this selection.")
                    .foregroundStyle(theme.palette.secondaryText).frame(height: chartHeight)
            }
            Text("Hover for exact daily totals. Dates without records do not establish zero activity.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            let undated = rows.filter { $0.sourceCivilDate == nil }.count
            if undated > 0 {
                Text("\(undated) undated transactions remain in the table and totals, outside this chart.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }.accessibilityIdentifier("periodOverview.activity")
    }

    private var seriesPicker: some View {
        Picker("Chart series", selection: Binding(get: { current?.id ?? "" }, set: { chosenSeries = $0; hoverDate = nil })) {
            ForEach(series) { Text($0.title).tag($0.id) }
        }.labelsHidden().tint(theme.palette.primaryText).frame(maxWidth: 300)
            .help("Changes only the chart. Accounts, totals and transactions stay the same.")
    }

    private func chart(_ observed: [PeriodOverviewDay], selected: Series, bounds: ClosedRange<Date>) -> some View {
        Chart {
            ForEach(observed) { day in
                ForEach(effects(selected), id: \.self) { effect in
                    if let money = day.totals.partitions[.init(currency: selected.currency, domain: selected.domain, effect: effect)],
                       let date = FinancialCalendar.instant(day.date) {
                        BarMark(x: .value("Date", date, unit: .day),
                            y: .value("Amount", NSDecimalNumber(decimal: money.amount).doubleValue),
                            width: .fixed(4))
                            .foregroundStyle(by: .value("Movement", title(effect)))
                            .position(by: .value("Movement", title(effect)))
                            .accessibilityLabel("\(day.date.presentation), \(title(effect)), \(exact(money))")
                    }
                }
            }
            if let hoverDate {
                RuleMark(x: .value("Date", hoverDate)).foregroundStyle(theme.palette.secondaryText)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
        }
        .chartForegroundStyleScale(domain: effects(selected).map(title),
            range: effects(selected).map { theme.financialEffectColor($0) })
        .chartXScale(domain: bounds)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self), let civil = FinancialCalendar.statement(date) {
                        Text(civil.presentation).font(theme.typography.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount.formatted(.number.precision(.fractionLength(0))
                            .locale(Locale(identifier: selected.currency.code == "INR" ? "en_IN" : "en_US"))))
                            .font(theme.typography.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        guard let plot = proxy.plotFrame else { return }
                        switch phase {
                        case .active(let location):
                            let frame = geometry[plot]
                            guard frame.contains(location) else { hoverDate = nil; return }
                            hoverDate = proxy.value(atX: location.x - frame.minX, as: Date.self)
                        case .ended: hoverDate = nil
                        }
                    }
            }
        }
        .frame(height: chartHeight)
        .environment(\.calendar, FinancialCalendar.calendar)
        .environment(\.timeZone, FinancialCalendar.calendar.timeZone)
    }

    private func hoverReadout(_ observed: [PeriodOverviewDay], selected: Series) -> some View {
        let day = hoverDate.flatMap(FinancialCalendar.statement)
        let match = day.flatMap { date in observed.first { $0.date == date } }
        return HStack(spacing: 14) {
            if let day {
                Text(day.presentation).fontWeight(.semibold)
                ForEach(effects(selected), id: \.self) { effect in
                    let money = match?.totals.partitions[.init(currency: selected.currency, domain: selected.domain, effect: effect)]
                    Text("\(title(effect)): \(money.map(exact) ?? "No recorded value")")
                        .foregroundStyle(money == nil ? theme.palette.secondaryText : theme.financialEffectColor(effect))
                }
            } else {
                Text("Daily totals · \(selected.currency.code)").foregroundStyle(theme.palette.secondaryText)
            }
        }.font(theme.typography.secondary).monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
    }

    private func exact(_ money: Money) -> String {
        money.currency.code + " " + ((try? money.canonicalDecimalString()) ?? NSDecimalNumber(decimal: money.amount).stringValue)
    }
}
