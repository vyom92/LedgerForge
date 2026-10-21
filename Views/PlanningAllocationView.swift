import SwiftUI

/// A selection-driven surface of the existing monthly editor. All amounts and
/// approval states come from its shared planning calculation and publication.
struct PlanningAllocationView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var planner: SalaryWorkspaceViewModel
    @ObservedObject private var analysis: PlanningAnalysisModel
    @ObservedObject private var store = FinancialIntelligenceStore.shared
    @ObservedObject private var categoryStore = CategoryStore.shared
    let availableWidth: CGFloat
    let onEditReserve: (ReserveDesignation?) -> Void
    let onAdvanced: () -> Void
    @State private var selection: AllocationRowID?

    init(planner: SalaryWorkspaceViewModel, availableWidth: CGFloat,
         onEditReserve: @escaping (ReserveDesignation?) -> Void,
         onAdvanced: @escaping () -> Void) {
        self.planner = planner
        self.analysis = planner.planningAnalysis
        self.availableWidth = availableWidth
        self.onEditReserve = onEditReserve
        self.onAdvanced = onAdvanced
    }

    private var result: SurplusAllocationCalculation? {
        if case .success(let value) = planner.allocationResult { return value }
        return nil
    }
    private var rows: [AllocationEditorRow] { planner.allocationRows }
    private var selectedRow: AllocationEditorRow? { rows.first { $0.id == selection } }
    /// The existing reserve projection does not consume investment intentions.
    /// Also inspect the canonical plan: a retained removal is not yet a release
    /// of an approved intention. Withhold estimates rather than invent overlap.
    private var investmentFundingNeedsReview: Bool {
        planner.plan.assistance?.surplusAllocation?.investments.isEmpty == false
            || planner.allocationCanonicalPlan?.assistance?.surplusAllocation?.investments.isEmpty == false
    }
    private var investmentFundingExplanation: String {
        "Reserve funding needs review. The reserve estimate does not include investment intentions, so funding and shortfall are unavailable to avoid counting the same cash twice."
    }
    private var currentProjection: PlanningProjection? {
        guard !investmentFundingNeedsReview,
              let projection = analysis.financialMCPProjection(for: planner), !projection.scenarioIsActive else { return nil }
        return projection
    }
    private var reserveLayout: AnyLayout {
        availableWidth >= 900
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            overview
            if let message = planner.allocationReviewMessage {
                qualification(message, symbol: "exclamationmark.triangle")
            }
            if let error = planner.errorMessage, error != planner.allocationReviewMessage {
                qualification(error, symbol: "exclamationmark.circle")
            }
            if planner.insightSelection.scenario.isActive {
                qualification("An unsaved what-if scenario is active in Planning details. Its reserve estimates are not shown as current funding here.", symbol: "info.circle")
            }
            if investmentFundingNeedsReview && !planner.allocationReserves.isEmpty {
                qualification(investmentFundingExplanation, symbol: "exclamationmark.triangle")
            }
            reserveLayout {
                reservePanel(title: "Qatar reserves", currency: "QAR")
                reservePanel(title: "India reserves", currency: "INR")
            }
            instructions
            if let row = selectedRow {
                PlanningAllocationInspector(planner: planner, row: row, availableWidth: availableWidth,
                    onRemove: { planner.removeAllocation(row.id); selection = nil })
            }
        }
        .font(theme.typography.body)
        .foregroundStyle(theme.palette.primaryText)
        .onAppear { refreshAnalysis() }
        .onDisappear { analysis.cancel() }
        .onChange(of: planner.plan) { _, _ in refreshAnalysis() }
        .onChange(of: planner.selectedHistoryAccountIDs) { _, _ in refreshAnalysis() }
        .onChange(of: planner.retainedRecurringOccurrenceIDs) { _, _ in refreshAnalysis() }
        .onChange(of: planner.recurringOccurrenceExclusions) { _, _ in refreshAnalysis() }
        .onChange(of: store.revision) { _, _ in refreshAnalysis() }
        .onChange(of: categoryStore.revision) { _, _ in refreshAnalysis() }
        .onChange(of: planner.insightSelection.scenario) { _, _ in refreshAnalysis() }
        .onChange(of: planner.month) { _, _ in selection = nil }
        .onChange(of: rows.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) { self.selection = nil }
        }
    }

    private var overview: some View {
        LFPanel(contentSpacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 32) {
                    surplusSummary
                    Spacer(minLength: 12)
                    plannedUsesSummary
                    Spacer(minLength: 12)
                    unallocatedSummary
                }
                VStack(alignment: .leading, spacing: 18) {
                    surplusSummary
                    HStack(alignment: .top, spacing: 32) {
                        plannedUsesSummary
                        Spacer(minLength: 12)
                        unallocatedSummary
                    }
                }
            }
            if let result, !result.transferCostsByCurrency.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Transfer costs already allowed for")
                    ForEach(result.transferCostsByCurrency, id: \.currency.code) { amount in
                        Text(PlanningAllocationFormat.money(amount)).monospacedDigit()
                    }
                }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Text("Planning amounts. Available cash and completed movements require supporting evidence.")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var surplusSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Surplus after obligations").font(theme.typography.secondary)
            Text(PlanningAllocationFormat.money(result?.monthlySurplus
                ?? (planner.hasValidCalculation ? planner.calculation.surplusAfterObligations : nil)))
                .font(theme.typography.headlineMoney).monospacedDigit()
            Text("Before surplus allocations")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var plannedUsesSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Planned uses by currency").font(theme.typography.secondary)
            if let result {
                ForEach(result.plannedUsesByCurrency, id: \.currency.code) { amount in
                    Text(PlanningAllocationFormat.money(amount))
                        .font(theme.typography.sectionTitle).monospacedDigit()
                }
            } else {
                Text(planner.plan.assistance?.surplusAllocation == nil ? "Not yet calculated" : "Needs review")
                    .font(theme.typography.sectionTitle)
            }
            Text("Keep in CBQ · " + PlanningAllocationFormat.money(planner.plan.keepInCBQ))
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text("Allocations, allowance and additional costs")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var unallocatedSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Unallocated by currency").font(theme.typography.secondary)
            if let result {
                ForEach(result.unallocated, id: \.currency.code) { amount in
                    Text(PlanningAllocationFormat.money(amount))
                        .font(theme.typography.sectionTitle).monospacedDigit()
                }
            } else {
                Text(planner.plan.assistance?.surplusAllocation == nil ? "Not yet calculated" : "Needs review")
                    .font(theme.typography.sectionTitle)
            }
        }
    }

    private func reservePanel(title: String, currency: String) -> some View {
        let reserves = planner.allocationReserves.filter { $0.target.currency == currency }
        return LFPanel(contentSpacing: 10) {
            HStack {
                Text(title).font(theme.typography.sectionTitle)
                Spacer()
                Text(currency).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            if reserves.isEmpty {
                Text("No saved reserve targets in \(currency).")
                    .foregroundStyle(theme.palette.secondaryText).padding(.vertical, 8)
                Button("Add reserve target") { onEditReserve(nil) }.lfSecondaryAction()
            } else {
                ForEach(reserves) { reserve in
                    reserveRow(reserve)
                    if reserve.id != reserves.last?.id { Divider() }
                }
            }
            Text(currency == "INR"
                 ? "NRO balances are protected emergency cash. Bank minimum-balance requirements need separate evidence review."
                 : "Saved targets do not establish that eligible, uncommitted reserve cash is available.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func reserveRow(_ reserve: ReserveDesignation) -> some View {
        let progress = currentProjection?.reserves.first { $0.id == reserve.id }
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reserve.title).font(theme.typography.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reserve.kind == .planningDeposit ? "Saved deposit target" : "Saved cash target")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(PlanningAllocationFormat.amount(reserve.target)).monospacedDigit()
                    .font(theme.typography.body.weight(.semibold)).fixedSize()
                Button { onEditReserve(reserve) } label: { Image(systemName: "pencil") }
                    .lfIconAction().help("Edit \(reserve.title)")
                    .accessibilityLabel("Edit \(reserve.title) target")
            }.frame(minHeight: 44)
            DisclosureGroup("Funding and planned additions") {
                VStack(alignment: .leading, spacing: 7) {
                    reserveDetail("Conditional funding after bills", progress?.fundedAfterBills, currency: reserve.target.currency)
                    reserveDetail("Conditional shortfall", progress?.gap, currency: reserve.target.currency)
                    if let contribution = planner.plan.assistance?.contributions.first(where: { $0.designationID == reserve.id }) {
                        HStack {
                            Text(planner.allocationStatus(for: .contribution(contribution.id)).title)
                            Spacer()
                            Text(PlanningAllocationFormat.amount(contribution.amount)).monospacedDigit()
                        }
                        Text(planner.allocationEvidenceStatus(for: .contribution(contribution.id)))
                            .foregroundStyle(theme.palette.secondaryText)
                    } else {
                        Text("No contribution selected this month").foregroundStyle(theme.palette.secondaryText)
                    }
                    Text(investmentFundingNeedsReview ? investmentFundingExplanation
                         : progress?.basis ?? "Eligible reserve funding has not been established.")
                        .foregroundStyle(theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    if let accountID = reserve.accountID,
                       let qualification = planner.allocationAccountQualification(accountID) {
                        Text(qualification).foregroundStyle(LFTheme.warning)
                    }
                }.font(theme.typography.secondary).padding(.top, 8)
            }.font(theme.typography.secondary)
        }
    }

    private func reserveDetail(_ title: String, _ amount: Decimal?, currency: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(amount.flatMap { try? Money(amount: $0, currency: currency) }
                .map { PlanningAllocationFormat.money($0) } ?? (investmentFundingNeedsReview ? "Unavailable · needs review" : "Not established"))
                .monospacedDigit().multilineTextAlignment(.trailing)
        }
    }

    private var instructions: some View {
        LFPanel(contentSpacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Monthly allocations").font(theme.typography.sectionTitle)
                    Spacer()
                    allocationActions
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Monthly allocations").font(theme.typography.sectionTitle)
                    allocationActions
                }
            }
            Text("Select a row to edit. Valid changes are approved in the plan after they are kept automatically.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if availableWidth >= 1180 { allocationTable }
            else { allocationList }
            if selection == nil {
                Text("Choose an allocation to see its funding, dates and evidence.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }

    private var allocationActions: some View {
        HStack(spacing: 12) {
            Menu {
                Menu("Reserve contribution") {
                    ForEach(planner.allocationReserves) { reserve in
                        Button(reserve.title) { selection = planner.addAllocationContribution(designationID: reserve.id) }
                            .disabled(planner.plan.assistance?.contributions.contains { $0.designationID == reserve.id } == true)
                    }
                    if planner.allocationReserves.isEmpty {
                        Button("Add reserve target…") { onEditReserve(nil) }
                    }
                }
                Button("Own-account transfer") { selection = planner.addAllocationTransfer() }
                Divider()
                Button("IBKR security") { selection = planner.addAllocationInvestment(kind: .ibkr) }
                Button("Indian mutual fund") { selection = planner.addAllocationInvestment(kind: .indianMutualFund) }
            } label: { Label("Add allocation", systemImage: "plus") }
                .lfMenuAction().disabled(!planner.canEdit)
                .accessibilityIdentifier("planner.allocation.add")
            Button("Planning details", action: onAdvanced).lfSecondaryAction()
        }
    }

    private var allocationTable: some View {
        Table(rows, selection: $selection) {
            TableColumn("Date") { row in Text(PlanningAllocationFormat.date(row.date)).frame(minHeight: 44) }
                .width(min: 72, ideal: 88, max: 102)
            TableColumn("Type") { row in Text(row.kind).lineLimit(2) }
                .width(min: 100, ideal: 120, max: 148)
            TableColumn("Source") { row in
                Text(row.sourceAccountID.map(planner.allocationAccountTitle) ?? "Not selected")
                    .lineLimit(2).help(row.sourceAccountID.map(planner.allocationAccountTitle) ?? "Not selected")
            }
                .width(min: 115, ideal: 135, max: 210)
            TableColumn("Destination") { row in Text(row.destination).lineLimit(2).help(row.destination) }
                .width(min: 145, ideal: 180, max: 300)
            TableColumn("Sent / allocated") { row in Text(PlanningAllocationFormat.amount(row.amount)).monospacedDigit() }
                .width(min: 108, ideal: 126, max: 170)
            TableColumn("Expected receipt") { row in Text(row.received.map { PlanningAllocationFormat.amount($0) } ?? "—").monospacedDigit() }
                .width(min: 108, ideal: 126, max: 170)
            TableColumn("Purpose") { row in Text(row.purpose).lineLimit(2) }
                .width(min: 115, ideal: 135, max: 210)
            TableColumn("Planning") { row in planningStatus(row.id) }
                .width(min: 108, ideal: 134, max: 170)
            TableColumn("Evidence") { row in Text(planner.allocationEvidenceStatus(for: row.id)).lineLimit(2) }
                .width(min: 108, ideal: 132, max: 170)
        }
        .font(theme.typography.body)
        .environment(\.defaultMinListRowHeight, 46)
        .frame(height: min(360, max(150, CGFloat(rows.count) * 52 + 40)))
        .accessibilityIdentifier("planner.allocation.table")
    }

    private var allocationList: some View {
        List(selection: $selection) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.destination).font(theme.typography.body.weight(.semibold))
                        Spacer(minLength: 16)
                        Text(PlanningAllocationFormat.amount(row.amount)).monospacedDigit()
                    }
                    Text(row.kind + " · " + PlanningAllocationFormat.date(row.date)
                         + " · " + (row.sourceAccountID.map(planner.allocationAccountTitle) ?? "Choose source account"))
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    HStack(spacing: 18) {
                        planningStatus(row.id)
                        Text(planner.allocationEvidenceStatus(for: row.id))
                        if let received = row.received {
                            Spacer(minLength: 4)
                            Text("Receipt " + PlanningAllocationFormat.amount(received)).monospacedDigit()
                        }
                    }.font(theme.typography.secondary)
                }.padding(.vertical, 8).tag(row.id)
            }
        }
        .listStyle(.inset)
        .frame(height: min(440, max(180, CGFloat(rows.count) * 100 + 16)))
        .accessibilityIdentifier("planner.allocation.list")
    }

    private func planningStatus(_ id: AllocationRowID) -> some View {
        let status = planner.allocationStatus(for: id)
        return Text(status.title)
            .foregroundStyle(status == .needsReview || status == .couldNotSave || status == .incompleteEntry
                             ? LFTheme.warning : theme.palette.primaryText)
            .lineLimit(2)
    }

    private func qualification(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private func refreshAnalysis() {
        analysis.refresh(plan: planner.plan, scenario: planner.insightSelection.scenario,
            selectedHistoryAccountIDs: planner.selectedHistoryAccountIDs,
            retainedRecurringOccurrenceIDs: planner.retainedRecurringOccurrenceIDs,
            excludedRecurringOccurrenceIDs: planner.recurringOccurrenceExclusions)
    }
}

/// Formatting only; no allocation arithmetic is performed by the SwiftUI view.
enum PlanningAllocationFormat {
    static func amount(_ value: PlanningAmount?) -> String {
        money(value.flatMap { try? $0.money() })
    }
    static func money(_ value: Money?) -> String {
        guard let value else { return "Not established" }
        return MoneyFormatting.planning(value)
    }
    static func date(_ value: String?) -> String {
        guard let value else { return "Monthly" }
        return (try? StatementDate(canonical: value))?.presentation ?? value
    }
}
