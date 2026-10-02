import AppKit
import SwiftUI

struct SalaryView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var viewModel: SalaryWorkspaceViewModel
    @ObservedObject var referenceSession: AlDarReferenceSession
    var onTransactions: (Set<String>) -> Void = { _ in }
    @ObservedObject private var salaryStore: SalaryStore = .shared
    @ObservedObject private var intelligenceStore: FinancialIntelligenceStore = .shared
    @ObservedObject private var transactions: TransactionStore = .shared
    private var section: String {
        get { viewModel.destinationSection }
        nonmutating set { viewModel.destinationSection = newValue }
    }
    @State private var confirmingDiscard = false
    @State private var showingFXDatePicker = false
    @State private var fxDateSelection = Date()
    @State private var billDateRowID: String?
    @State private var billDateSelection = Date()
    @State private var showingManualFX = false
    @State private var showingPlanningAccounts = false
    @State private var showingSalaryCycle = false
    @State private var reviewingPayslip: SalaryStatement?
    @State private var historyStatementID: String?
    @State private var showingAdjustments = false
    @State private var showingRateDetails = false
    @State private var choosingAccounts: String?
    @State private var balanceDetailsID: String?
    @State private var billDetailsID: String?
    @FocusState private var focusedInput: String?

    private var amountWidth: CGFloat {
        let values = viewModel.plan.balances.compactMap(\.money)
            + (viewModel.plan.qatarCommitments + viewModel.plan.indiaCommitments).map(\.money)
            + viewModel.plan.deductions.map(\.money)
            + [viewModel.plan.expectedFixedEarnings, viewModel.plan.expectedVariableEarnings]
        let font = theme.typography.nativeFont(.body, tabularDigits: true)
        return max(120, ceil(values.map { (MoneyFormatting.display($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0) + 16)
    }
    private var minimumColumn: CGFloat {
        let label = ("Starting cash" as NSString).size(withAttributes: [.font: theme.typography.nativeFont(.body)]).width
        return max(580, label + amountWidth + 270)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - theme.spacing.pagePadding * 2)
            let wide = width >= minimumColumn * 2 + 18
            let columnWidth = wide ? (width - 18) / 2 : width
            let layout = wide ? AnyLayout(HStackLayout(alignment: .top, spacing: 18)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header(width: width)
                    Picker("Planning section", selection: Binding(get: { section }, set: { destination in
                        // AppKit's segmented-control callback can run inside a
                        // SwiftUI update. Publish navigation after that callback
                        // unwinds; the main queue preserves selection order.
                        DispatchQueue.main.async {
                            guard viewModel.destinationSection != destination else { return }
                            viewModel.destinationSection = destination
                        }
                    })) {
                        Text("Monthly plan").tag("This Month")
                        Text("Plan insights").tag("Plan insights")
                        Text("Salary History").tag("Salary History")
                    }.pickerStyle(.segmented).font(theme.typography.button).frame(maxWidth: 600)
                        .accessibilityLabel("Planning section")
                    if section != "Salary History" {
                        planningDates
                        if !viewModel.historyScopeAccounts.isEmpty {
                            Menu(viewModel.selectedHistoryAccountIDs.isEmpty ? "Current accounts" : "Current + selected history") {
                                Button("Current accounts") { viewModel.selectCurrentAccountScope() }
                                Divider()
                                ForEach(viewModel.historyScopeAccounts) { account in
                                    if let id = account.repositoryAccountId {
                                        Toggle(account.selectionTitle,
                                            isOn: Binding(get: { viewModel.selectedHistoryAccountIDs.contains(id) },
                                                set: { viewModel.setHistoryAccountSelected(id, selected: $0) }))
                                    }
                                }
                            }.help("History-only accounts are excluded until you select them here.")
                        }
                    }
                }.frame(width: width, alignment: .leading)
                    .padding(.horizontal, theme.spacing.pagePadding).padding(.top, 12).padding(.bottom, 12)
                Divider()
                if section == "Salary History" {
                    SalaryHistoryView(groups: viewModel.historyGroups, selectedStatementID: $historyStatementID)
                        .padding(theme.spacing.pagePadding)
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    if section != "Salary History" {
                        ForEach(viewModel.payslipProposals) { statement in
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(AppDateDisplay.month(statement.evidence.financialPeriod.canonical)) payslip is ready")
                                        .font(theme.typography.body.weight(.semibold))
                                    Text("\(MoneyFormatting.display(statement.evidence.printedNet)) net pay · review before adding it to your plan")
                                        .font(theme.typography.body)
                                }
                                Spacer()
                                Button("Review salary draft") {
                                    viewModel.switchMonth(to: statement.evidence.financialPeriod)
                                    if viewModel.month == statement.evidence.financialPeriod && viewModel.canEdit { reviewingPayslip = statement }
                                }.lfPrimaryAction().disabled(!viewModel.canEdit)
                            }.padding(16).background(theme.palette.controlSurface, in: RoundedRectangle(cornerRadius: theme.radius.control))
                        }
                    }
                    if section == "This Month" {
                        if let error = viewModel.errorMessage { Text(error).foregroundStyle(LFTheme.warning).font(theme.typography.secondary) }
                        monthlyOverview(width: width)
                        if viewModel.plan.calculationVersion == .budgetV1 {
                            layout {
                                qatarColumn(width: columnWidth).frame(maxWidth: .infinity, alignment: .leading)
                                indiaColumn(width: columnWidth).frame(maxWidth: .infinity, alignment: .leading)
                            }.disabled(!viewModel.canEdit)
                        }
                    } else if section == "Plan insights" {
                        PlanningInsightsView(planner: viewModel, selection: $viewModel.insightSelection, model: viewModel.planningAnalysis, onTransactions: onTransactions, onMonthlyPlan: { section = "This Month" }, availableWidth: width)
                    }
                }.frame(width: width, alignment: .leading).padding(theme.spacing.pagePadding)
                    .font(theme.typography.body)
                }
                }
            }
        }
        .confirmationDialog("Discard this draft and reload the current database?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard and reload", role: .destructive) { viewModel.discardAndReload() }
            Button("Keep draft", role: .cancel) {}
        }
        .sheet(isPresented: $showingPlanningAccounts) {
            PlanningAccountsEditor(accounts: viewModel.availablePlanningAccounts, workspaceID: viewModel.plan.workspaceID, generation: viewModel.generation)
        }
        .sheet(isPresented: $showingSalaryCycle) {
            PlanningSalaryCycleEditor(plan: viewModel.plan, metadata: intelligenceStore.snapshot, onApply: { viewModel.setSalaryCycle($0) })
        }
        .sheet(item: $reviewingPayslip) { statement in
            PayslipProposalEditor(statement: statement, plan: viewModel.plan, accounts: viewModel.eligibleAccounts) { accountID in
                if viewModel.applyPayslip(statement, accountID: accountID) { reviewingPayslip = nil; section = "This Month"; return true }
                return false
            }
        }
        .onAppear {
            viewModel.plannerOpened()
            viewModel.receiveSharedReference(referenceSession.legs[.inr])
            showingManualFX = viewModel.plan.referenceMode == .manual
        }
        .onDisappear { viewModel.flushPendingEntries() }
        .onReceive(referenceSession.$legs) { viewModel.receiveSharedReference($0[.inr]) }
        .onChange(of: viewModel.month) { _, _ in
            showingManualFX = viewModel.plan.referenceMode == .manual
        }
    }

    @ViewBuilder private func monthlyOverview(width: CGFloat) -> some View {
        if viewModel.plan.calculationVersion == .legacy {
            LFPanel(title: "Your saved monthly plan") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Continue with your saved estimates in the new worksheet. Changes in the monthly worksheet are kept automatically.")
                        .font(theme.typography.body)
                    valueRow("Expected net salary", viewModel.calculation.expectedNet, truth: "Saved estimate")
                    valueRow("Previously planned investment", viewModel.plan.plannedInvestment, truth: "From your saved plan")
                    valueRow("Saved amount left over", viewModel.calculation.finalQARBuffer, truth: "From your saved plan")
                    Button("Open monthly worksheet") { viewModel.adoptBudgetPlanning() }
                        .lfSecondaryAction().disabled(!viewModel.canEdit)
                }
            }
        } else {
            comparison(width: width)
        }
    }


    private func header(width: CGFloat) -> some View {
        let layout = width >= 1060 ? AnyLayout(HStackLayout(alignment: .center, spacing: 20)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        return VStack(alignment: .leading, spacing: 8) {
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget Planning").font(theme.typography.pageTitle)
                    Text(section == "Salary History" ? "Salary history · Read-only" : "Monthly estimates · \(fullMonthTitle(viewModel.month))")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if section == "Salary History" {
                    HStack(spacing: 16) {
                        if viewModel.hasUnsavedDrafts {
                            Label("\(monthNames[viewModel.month.month - 1]) · \(viewModel.statusText)", systemImage: "circle.fill")
                                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        }
                        Button("Return to Monthly plan") { section = "This Month" }.lfSecondaryAction()
                    }
                } else {
                    planningControls
                }
            }
            if section != "Salary History" {
                if viewModel.saveState == .committedNeedsRefresh {
                    Button("Reload saved plan") { viewModel.retryCanonicalRefresh() }.lfSecondaryAction()
                } else if [.providerChanged, .canonicalChanged, .committedToPreviousProvider].contains(viewModel.saveState) {
                    Button("Discard draft and reload") { confirmingDiscard = true }.lfSecondaryAction()
                }
            }
        }
    }

    private var planningControls: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(1...12, id: \.self) { number in
                    Button(monthNames[number - 1]) { selectPlanningMonth(number, year: viewModel.month.year) }
                        .disabled(viewModel.month.year < 2026 || (viewModel.month.year == 2026 && number < 9))
                }
                let earlier = viewModel.availableMonths.filter { !SalaryWorkspaceViewModel.planningMonths.contains($0) }
                if !earlier.isEmpty {
                    Divider()
                    Menu("Saved history") {
                        ForEach(earlier, id: \.self) { month in
                            Button(fullMonthTitle(month)) { viewModel.switchMonth(to: month) }
                        }
                    }
                }
            } label: {
                Label(monthNames[viewModel.month.month - 1], systemImage: "calendar")
            }.lfMenuAction().accessibilityLabel("Planning month")
            Menu {
                ForEach(2026...2099, id: \.self) { year in
                    Button(String(year)) {
                        selectPlanningMonth(year == 2026 ? max(9, viewModel.month.month) : viewModel.month.month, year: year)
                    }
                }
            } label: { Text(String(viewModel.month.year)) }
                .lfMenuAction().accessibilityLabel("Planning year").accessibilityValue(String(viewModel.month.year))
            Text(!SalaryWorkspaceViewModel.planningMonths.contains(viewModel.month) ? "Saved plan · read only" : viewModel.statusText)
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Spacer(minLength: 4)
            Button("Planning accounts") { showingPlanningAccounts = true }.lfSecondaryAction().disabled(!viewModel.canEdit)
        }
        .disabled(viewModel.saveState == .saving || viewModel.saveState == .committedNeedsRefresh)
    }

    private var planningDates: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let cycle = viewModel.plan.assistance?.salaryCycle {
                Text("Bills: \(cycle.billRange) · Recurring: \(cycle.recurringRange)")
                    .foregroundStyle(theme.palette.secondaryText)
                Spacer(minLength: 0)
                Text("\(cycle.receivedSalaryID == nil ? "Expected payday" : "Salary received") \(cycle.recurringStart.presentation)")
                if cycle.needsPreviousBoundaryReview(in: intelligenceStore.snapshot) {
                    Label("Review changed salary dates", systemImage: "exclamationmark.circle").foregroundStyle(LFTheme.warning)
                }
            } else {
                Text("Calendar-month plan · \(fullMonthTitle(viewModel.month))").foregroundStyle(theme.palette.secondaryText)
                Spacer(minLength: 0)
            }
            Button(viewModel.plan.assistance?.salaryCycle == nil ? "Use salary dates" : "Edit payday") { showingSalaryCycle = true }
                .lfSecondaryAction().disabled(!viewModel.canEdit)
        }.font(theme.typography.secondary)
    }

    private var monthNames: [String] { ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"] }
    private func fullMonthTitle(_ month: SelectedStatementMonth) -> String { "\(monthNames[month.month - 1]) \(month.year)" }
    private func selectPlanningMonth(_ number: Int, year: Int) {
        if let month = try? SelectedStatementMonth(year: year, month: number) { viewModel.switchMonth(to: month) }
    }

    private func comparison(width: CGFloat) -> some View {
        let calculation = viewModel.calculation
        let layout = width >= max(660, amountWidth * 3 + 100)
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 24))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
        return LFPanel(contentSpacing: 8) {
            layout {
                summary("Available to transfer", calculation.transferablePrincipal, secondary: calculation.estimatedINR)
                summary("Minimum reqd transfer", calculation.indiaFundingShortfall, secondary: calculation.requiredQARPrincipal)
                summary("Balance available",
                        calculation.finalQARBuffer, secondary: viewModel.finalBufferINREstimate, emphasize: true)
            }
            if let deficit = calculation.qatarObligationShortfall, deficit.amount > 0 {
                Label("Qatar bills need \(display(deficit)) more cash before any transfer.", systemImage: "exclamationmark.circle")
                    .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
            if let gap = calculation.qatarReserveGap, gap.amount > 0 {
                Text("Funds after Qatar bills are \(display(gap)) below Keep in CBQ.")
                    .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
            if !viewModel.hasValidCalculation {
                Text("Complete the highlighted entries to calculate.").font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func summary(_ label: String, _ amount: Money?, secondary: Money?, emphasize: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text(display(amount)).font(theme.typography.font(.headlineMoney, tabularDigits: true).weight(.semibold))
                .foregroundStyle(!viewModel.hasValidCalculation || (amount?.amount ?? 0) < 0 ? LFTheme.warning : emphasize && amount != nil ? LFTheme.success : theme.palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let secondary { Text(display(secondary)).font(theme.typography.font(.secondary, tabularDigits: true)).foregroundStyle(theme.palette.secondaryText) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func countryHeading(_ title: String, currency: String) -> some View {
        HStack {
            Text(title).font(theme.typography.sectionTitle)
            Spacer()
            Text(currency).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func qatarColumn(width: CGFloat) -> some View {
        LFPanel(contentSpacing: 12) {
            countryHeading("Qatar", currency: "QAR")
            cashHeading("Starting cash", currency: "QAR")
            balances(currency: "QAR", width: width)
            Divider()
            salarySummary(width: width)
            Divider()
            Text("Qatar bills").font(theme.typography.body.weight(.semibold))
            commitmentRows(region: "qatar", values: viewModel.plan.qatarCommitments, width: width)
            valueRow("Total bills", viewModel.calculation.qatarCommitments, truth: "")
            Divider()
            moneyRow("Keep in CBQ", field: .reserve, width: width)
                .help("Money retained in this worksheet. Saved long-term reserve targets apply separately in Plan insights.")
            moneyRow("Transfer fee", field: .fee, width: width)
            recurringDetails(currency: "QAR")
        }
    }

    private func salarySummary(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            let sourceNet = viewModel.plan.assistance?.payslipFunding.flatMap { try? $0.net.money() }
            HStack(alignment: .firstTextBaseline) {
                Text(sourceNet == nil && hasReceivedSalary ? "Salary in starting cash" : "Expected pay")
                Spacer(minLength: 10)
                if let sourceNet {
                    Text(MoneyFormatting.display(sourceNet)).font(theme.typography.sectionTitle).monospacedDigit()
                } else if hasReceivedSalary {
                    Text(receivedSalaryAmount.map { MoneyFormatting.display($0) } ?? "Salary amount unavailable")
                        .font(theme.typography.sectionTitle).monospacedDigit()
                } else {
                    Text(display(viewModel.calculation.expectedNet)).font(theme.typography.sectionTitle).monospacedDigit()
                }
            }
            HStack(alignment: .top) {
                Text(sourceNet != nil ? viewModel.payslipReceiptState?.explanation ?? "Check salary payment" : hasReceivedSalary ? receivedSalaryContext : "Your estimate")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Adjustments") { showingAdjustments = true }.buttonStyle(.link)
                    .popover(isPresented: $showingAdjustments) { salaryAdjustments(width: max(480, minimumColumn)).padding(20).frame(width: max(520, minimumColumn + 40)) }
            }
            if sourceNet != nil || hasReceivedSalary {
                let adjustment = viewModel.calculation.totalDeductions.flatMap { try? (viewModel.plan.expectedFixedEarnings + viewModel.plan.expectedVariableEarnings) - $0 }
                if let adjustment, adjustment.amount != 0 {
                    Text("Adjustments: \(MoneyFormatting.display(adjustment))")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
    }

    private func salaryAdjustments(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Salary adjustments").font(theme.typography.sectionTitle)
            if viewModel.plan.assistance?.payslipFunding != nil || !receivedSalaryContext.isEmpty {
                Text("Payroll deductions are already included in take-home salary.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Text("Changes are kept automatically for this month.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            if let source = viewModel.plan.assistance?.payslipFunding, let money = try? source.net.money() {
                valueRow("Payslip net", money, truth: viewModel.payslipReceiptState?.explanation ?? "Check salary payment")
                if viewModel.canAcknowledgePayslipBalance && viewModel.payslipReceiptState != .acknowledgedBalance {
                    Button("This captured balance includes my salary") { viewModel.acknowledgePayslipInCapturedBalance() }.lfSecondaryAction()
                }
                Button("Remove payslip estimate") { viewModel.removePayslipEstimate() }.lfSecondaryAction()
            }
            moneyRow("Fixed earnings", field: .fixed, width: width)
            moneyRow("Variable earnings", field: .variable, width: width)
            Text("Additional deductions").font(theme.typography.body.weight(.semibold))
            deductions(width: width)
            valueRow("Income included this month", viewModel.calculation.expectedNet, truth: "Received salary in starting cash is not added again")
            HStack { Spacer(); Button("Done") { showingAdjustments = false }.lfPrimaryAction() }
        }.font(theme.typography.body)
    }

    private func indiaColumn(width: CGFloat) -> some View {
        LFPanel(contentSpacing: 12) {
            countryHeading("India", currency: "INR")
            Text("Bills in India").font(theme.typography.body.weight(.semibold))
            commitmentRows(region: "india", values: viewModel.plan.indiaCommitments, width: width)
            valueRow("Total needed", viewModel.calculation.indiaCommitments, truth: "")
            Divider()
            cashHeading("Existing INR funds", currency: "INR")
            balances(currency: "INR", width: width)
            valueRow("Using existing funds", viewModel.calculation.selectedINRLiquidity, truth: "")
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.plan.referenceMode == .manual ? "Your monthly rate" : "Plan's Al Dar reference")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    Text(viewModel.plan.referenceMode == .manual
                         ? "1 QAR = \(viewModel.rawText["fx.rate"] ?? "Unavailable") INR"
                         : viewModel.plan.effectiveAlDarReference.map { "1 QAR = \($0.displayRate) INR" } ?? "Rate unavailable")
                    if viewModel.plan.referenceMode == .alDar, let quote = viewModel.plan.effectiveAlDarReference {
                        Text("Reference fetched \(AppDateDisplay.isoTimestamp(quote.fetchedAtISO))")
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                }
                Spacer()
                Button("Rate details") { showingRateDetails = true }.buttonStyle(.link)
                    .popover(isPresented: $showingRateDetails) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Current public reference").font(theme.typography.body.weight(.semibold))
                            AlDarFXCard(session: referenceSession)
                            DisclosureGroup("Use your own rate for this month", isExpanded: $showingManualFX) {
                                input("INR for 1 QAR", key: "fx.rate", binding: Binding(get: { viewModel.rawText["fx.rate"] ?? "" }, set: { viewModel.setFX(rateText: $0, dateText: viewModel.rawText["fx.date"] ?? "") }))
                                manualFXObservationDate
                                Button("Use Al Dar instead") { viewModel.useSharedAlDar() }.lfSecondaryAction()
                            }
                            Button("Done") { showingRateDetails = false }.lfSecondaryAction()
                        }.padding(20).frame(width: max(480, AlDarFXCard.minimumWidth(theme: theme, legs: referenceSession.legs) + 40))
                    }
            }
            if viewModel.plan.referenceMode == .alDar && viewModel.plan.effectiveAlDarReference == nil {
                Text("Al Dar is unavailable. Use your own rate in Rate details.").font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
            recurringDetails(currency: "INR")
        }
    }

    @ViewBuilder private func recurringDetails(currency: String) -> some View {
        if intelligenceStore.snapshot?.recurring.contains(where: { $0.revisions.contains { $0.amount.currency == currency } }) == true {
            DisclosureGroup("Recurring payments") { confirmedCommitments(currency: currency) }
                .font(theme.typography.secondary)
        }
    }

    private func moneyRow(_ title: String, field: SalaryWorkspaceViewModel.MoneyField, width: CGFloat) -> some View {
        let layout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        return layout {
            Text(title).frame(maxWidth: .infinity, alignment: .leading)
            input(title, key: field.rawValue, placeholder: "0", currency: "QAR", binding: Binding(get: { viewModel.amountInputText(field.rawValue) }, set: { _ = viewModel.updateMoney(field, text: $0) }))
                .frame(maxWidth: amountWidth)
        }.frame(maxWidth: max(540, amountWidth + 220), alignment: .leading)
    }

    private var hasReceivedSalary: Bool { !(viewModel.plan.assistance?.appliedSalaryIDs.isEmpty ?? true) }

    private var receivedSalaryAmount: Money? {
        let ids = Set(viewModel.plan.assistance?.appliedSalaryIDs ?? [])
        let rows = transactions.transactions.filter { $0.repositoryTransactionId.map(ids.contains) == true }
        let credits = rows.compactMap(\.creditMoney)
        guard !ids.isEmpty, rows.count == ids.count, credits.count == rows.count,
              credits.allSatisfy({ $0.currency.code == "QAR" }), let first = credits.first else { return nil }
        return try? credits.dropFirst().reduce(first) { try $0 + $1 }
    }

    private var receivedSalaryContext: String {
        let ids = Set(viewModel.plan.assistance?.appliedSalaryIDs ?? [])
        let values = intelligenceStore.snapshot?.salaries.filter { ids.contains($0.id) } ?? []
        let dates = values.compactMap { try? StatementDate(canonical: $0.financialDate) }.sorted().map(\.presentation)
        guard !ids.isEmpty else { return "" }
        let timing = dates.isEmpty ? "Applied salary" : "Salary received \(dates.joined(separator: ", "))"
        return "\(timing) is already included in the captured account funds for this plan. It is not added again as expected income."
    }

    private func confirmedCommitments(currency: String) -> some View {
        let definitions = (intelligenceStore.snapshot?.recurring ?? []).filter {
            $0.revisions.contains { $0.amount.currency == currency }
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(definitions) { definition in
                let due = recurringDetail(definition)
                let next = nextCommitmentDate(definition)
                VStack(alignment: .leading, spacing: 3) {
                    Text(definition.title).font(theme.typography.body.weight(.semibold))
                    if !definition.isEnabled {
                        Text("Recurring rule is paused")
                    } else if viewModel.excludedPlanningAccountIDs.contains(definition.accountID) {
                        Text("Funding account removed from planning · add it back or edit the recurring commitment")
                    } else if let due {
                        Text("Due \(due.date.presentation) · \(due.amount.map { MoneyFormatting.display($0) } ?? "Amount unavailable") · \(due.included ? "Included in this month" : "Not included in this month")")
                    } else if let next {
                        Text("Outside this salary plan · next due \(next.presentation)")
                    } else {
                        Text("No scheduled payment in this salary plan")
                    }
                }.font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            if !definitions.isEmpty {
                Button("Review recurring payments") {
                    viewModel.insightSelection.section = "Commitments"; section = "Plan insights"
                }.lfSecondaryAction()
            }
        }
    }

    private func recurringSelections(_ definition: RecurringDefinition, month: SelectedStatementMonth) -> [(RecurringOccurrenceSelection, RecurringRevision)] {
        let metadata = intelligenceStore.snapshot
        let retained = viewModel.retainedRecurringOccurrenceIDs
            .union(metadata?.occurrences.map(\.id) ?? [])
            .union((metadata?.plans ?? []).flatMap { $0.appliedRecurringIDs.keys })
        let generated = PlanningIntelligence.dueDate(definition: definition, month: month)
        return PlanningIntelligence.occurrenceSelections(definitionID: definition.id, month: month,
            generatedDate: generated?.0, retaining: retained, excluding: viewModel.recurringOccurrenceExclusions)
            .compactMap { selection -> (RecurringOccurrenceSelection, RecurringRevision)? in
                guard definition.endsOn.map({ selection.date.canonical <= $0 }) ?? true,
                      let revision = generated.flatMap({ $0.0 == selection.date ? $0.1 : nil }) ?? definition.revision(on: selection.date) else { return nil }
                return (selection, revision)
            }
    }

    private func recurringDetail(_ definition: RecurringDefinition) -> (date: StatementDate, amount: Money?, included: Bool)? {
        let plan = viewModel.plan
        let firstMonth = try! SelectedStatementMonth(year: plan.recurringStart.year, month: plan.recurringStart.month)
        let lastMonth = try! SelectedStatementMonth(year: plan.recurringEnd.year, month: plan.recurringEnd.month)
        let candidates = Set([firstMonth, lastMonth]).flatMap { recurringSelections(definition, month: $0) }
            .filter { plan.includesRecurring($0.0.date) }
        guard let (selection, revision) = candidates.min(by: { $0.0.date < $1.0.date }) else { return nil }
        let rowID = plan.assistance?.appliedRecurringIDs[selection.id]
        let row = (plan.qatarCommitments + plan.indiaCommitments).first { $0.id == rowID }
        return (row.flatMap { plan.dueDate(for: $0) } ?? selection.date,
                row?.money ?? (try? revision.amount.money()), row?.included == true && !selection.isExcludedFromPlan)
    }

    private func nextCommitmentDate(_ definition: RecurringDefinition) -> StatementDate? {
        // Inspect schedule boundaries, not arbitrary future months. The first
        // effective rule may begin long after the selected worksheet month.
        let starts = [viewModel.month] + definition.revisions.compactMap { try? SelectedStatementMonth(canonical: String($0.effectiveFrom.prefix(7))) }
        let months = starts.flatMap { month -> [SelectedStatementMonth] in
            let next = try? SelectedStatementMonth(year: month.month == 12 ? month.year + 1 : month.year, month: month.month == 12 ? 1 : month.month + 1)
            return [month] + [next].compactMap { $0 }
        }.filter { $0 > viewModel.month }.sorted()
        return months.flatMap { recurringSelections(definition, month: $0).map { $0.0.date } }.sorted().first
    }

    private func input(_ title: String, key: String, placeholder: String? = nil, currency: String? = nil, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(title, text: Binding(get: { binding.wrappedValue }, set: { value in
                // AppKit can echo the displayed blank on focus. An untouched
                // zero stays untouched until the owner actually changes text.
                if value != binding.wrappedValue { binding.wrappedValue = value }
            }), prompt: Text(placeholder ?? title))
                .font(theme.typography.body).multilineTextAlignment(placeholder == "0" ? .trailing : .leading).lfTextField()
                .accessibilityLabel(title).accessibilityIdentifier("planner." + key)
                .focused($focusedInput, equals: key)
            if let error = viewModel.fieldErrors[key] {
                Text(error).font(theme.typography.secondary).foregroundStyle(LFTheme.warning).fixedSize(horizontal: false, vertical: true)
            } else if focusedInput == key, let currency, let words = PlannerInputCodec.amountInWords(binding.wrappedValue, currency: currency, locale: .current) {
                Text(words).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .multilineTextAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Amount in words: " + words)
            }
        }
    }

    private func cashHeading(_ title: String, currency: String) -> some View {
        HStack {
            Text(title).font(theme.typography.body.weight(.semibold))
            Spacer()
            Button("Choose accounts") { choosingAccounts = currency }.buttonStyle(.link)
                .popover(isPresented: Binding(get: { choosingAccounts == currency }, set: { if !$0 { choosingAccounts = nil } })) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(currency) cash for this month").font(theme.typography.sectionTitle)
                        ForEach(viewModel.eligibleAccounts.filter { $0.nativeCurrency.code == currency && !$0.isHistoryOnly }, id: \.id) { account in
                            Toggle(isOn: Binding(
                                get: { viewModel.isAccountIncluded(account) },
                                set: { viewModel.setAccountIncluded(account, included: $0) })) {
                                    LFAccountLabel(title: account.preferredDisplayName, detail: account.selectionContext)
                                }
                        }
                        let history = viewModel.historicalPlanningAccounts.filter { $0.currencyCode == currency }
                        if !history.isEmpty {
                            DisclosureGroup("History-only accounts") {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Excluded by default. Select an account to include its balance while viewing this month.")
                                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                                    ForEach(history) { account in
                                        Toggle(isOn: Binding(get: { viewModel.isAccountIncluded(account) },
                                            set: { viewModel.setAccountIncluded(account, included: $0) })) {
                                            LFAccountLabel(title: account.preferredDisplayName, detail: account.selectionContext)
                                        }
                                    }
                                }.padding(.top, 8)
                            }
                        }
                        Text("All-month availability is managed in Planning accounts.")
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        Button("Done") { choosingAccounts = nil }.lfSecondaryAction()
                    }.padding(20).frame(minWidth: 360)
                }
        }
    }

    private func balances(currency: String, width: CGFloat) -> some View {
        let accounts = viewModel.eligibleAccounts.filter { $0.nativeCurrency.code == currency }
        let selected = accounts.filter { account in viewModel.plan.balances.contains { $0.accountID == account.repositoryAccountId && $0.included } }
        return VStack(alignment: .leading, spacing: 10) {
            if selected.isEmpty {
                Text(accounts.isEmpty ? "No eligible \(currency) bank accounts." : "No cash accounts selected. Choose accounts to include funds.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            ForEach(selected, id: \.id) { account in
                let balance = viewModel.plan.balances.first { $0.accountID == account.repositoryAccountId }
                let key = "balance.\(account.repositoryAccountId ?? "")"
                let rowLayout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .top, spacing: 10)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                VStack(alignment: .leading, spacing: 4) {
                    rowLayout {
                        Toggle(account.preferredDisplayName, isOn: Binding(get: { balance?.included ?? false }, set: { viewModel.setAccountIncluded(account, included: $0) }))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .top, spacing: 8) {
                            input("\(account.preferredDisplayName) planning balance", key: key, placeholder: "0", currency: currency,
                                  binding: Binding(get: { viewModel.amountInputText(key) }, set: { viewModel.setManualBalance(account, text: $0) }))
                                .frame(width: amountWidth)
                            Button("Capture current") { viewModel.captureAccountBalance(account) }.lfSecondaryAction()
                        }
                    }
                    HStack(alignment: .top) {
                        Text([account.sourceAccountLabel ?? account.identitySummaries.first?.redactedValue,
                              balance.map { cashBasis($0) }].compactMap { $0 }.joined(separator: " · "))
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        Spacer(minLength: 4)
                        Button("Details") { balanceDetailsID = key }.buttonStyle(.link)
                            .popover(isPresented: Binding(get: { balanceDetailsID == key }, set: { if !$0 { balanceDetailsID = nil } })) {
                                VStack(alignment: .leading, spacing: 10) {
                                    LFAccountLabel(title: account.preferredDisplayName, detail: account.selectionContext)
                                        .font(theme.typography.body.weight(.semibold))
                                    Text(balance.map { viewModel.balanceProvenanceText($0) } ?? "Enter a planning balance")
                                        .font(theme.typography.body)
                                    if !receivedSalaryContext.isEmpty { Text(receivedSalaryContext).font(theme.typography.secondary) }
                                }.padding(20).frame(width: 400)
                            }
                    }
                    if viewModel.unavailableCurrentBalanceAccountIDs.contains(account.repositoryAccountId ?? "") {
                        Text("Couldn’t refresh this balance. Your estimate is unchanged.").font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    }
                }
            }
            ForEach(viewModel.plan.balances.filter { balance in balance.nativeCurrency.code == currency && !viewModel.excludedPlanningAccountIDs.contains(balance.accountID) && !accounts.contains(where: { $0.repositoryAccountId == balance.accountID }) }) { balance in
                if let account = viewModel.retainedBalanceAccount(id: balance.accountID) {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Toggle(account.preferredDisplayName, isOn: Binding(
                            get: { viewModel.plan.balances.first { $0.id == balance.id }?.included ?? false },
                            set: { viewModel.setAccountIncluded(account, included: $0) }))
                        input("\(account.preferredDisplayName) planning balance", key: "balance.\(balance.accountID)", placeholder: "0", currency: currency,
                              binding: Binding(get: { viewModel.amountInputText("balance.\(balance.accountID)") }, set: { viewModel.setManualBalance(account, text: $0) }))
                            .frame(width: amountWidth)
                        Text(account.isHistoryOnly ? "History-only account · retained for this month" : "Saved account · retained for this month")
                            .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                        DisclosureGroup("Balance details") {
                            Text(viewModel.balanceProvenanceText(balance)).font(theme.typography.secondary)
                        }
                    }
                } else {
                    Text("Saved account unavailable · \(display(balance.money))").foregroundStyle(LFTheme.warning)
                }
            }
        }
    }

    private func cashBasis(_ balance: FundingPlanBalance) -> String {
        if case .manual = balance.provenance { return "Your estimate" }
        return balance.financialBalanceDate.map { "Balance as of \($0.presentation)" } ?? "Balance date unavailable"
    }

    private func deductions(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(viewModel.plan.deductions) { row in
                let layout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .top, spacing: 8)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                layout {
                    input("Deduction name", key: "deduction.label.\(row.id)", binding: Binding(get: { viewModel.rawText["deduction.label.\(row.id)"] ?? row.label }, set: { viewModel.editDeduction(id: row.id, label: $0) }))
                    input("Deduction QAR", key: "deduction.amount.\(row.id)", placeholder: "0", currency: "QAR", binding: Binding(get: { viewModel.amountInputText("deduction.amount.\(row.id)") }, set: { viewModel.editDeduction(id: row.id, amount: $0) })).frame(maxWidth: amountWidth)
                    Button(role: .destructive) { viewModel.removeDeduction(id: row.id) } label: { Image(systemName: "minus.circle") }.lfIconAction().accessibilityLabel("Remove deduction")
                }
                Toggle("This month only", isOn: Binding(get: { !row.recurs }, set: { viewModel.editDeduction(id: row.id, recurs: !$0) }))
                    .font(theme.typography.caption)
            }
            Button { viewModel.addDeduction() } label: { Label("Add deduction", systemImage: "plus") }.lfSecondaryAction()
        }.padding(.top, 6)
    }

    private func commitmentRows(region: String, values: [FundingPlanCommitment], width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values.filter { $0.isInAccountScope(excluding: viewModel.excludedHistoryAccountIDs, fundingOverrides: viewModel.plan.assistance?.billFundingAccounts) }) { value in
                let layout = width >= minimumColumn ? AnyLayout(HStackLayout(alignment: .top, spacing: 8)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                layout {
                    HStack(alignment: .center, spacing: 6) {
                        Toggle("Include", isOn: Binding(get: { value.included }, set: { viewModel.editCommitment(region: region, id: value.id, field: "included", text: String($0)) }))
                            .labelsHidden().accessibilityLabel("Include \(value.label)")
                        input("Bill name", key: "label.\(value.id)", binding: Binding(get: { viewModel.rawText["label.\(value.id)"] ?? value.label }, set: { viewModel.editCommitment(region: region, id: value.id, field: "label", text: $0) }))
                    }.frame(maxWidth: .infinity)
                    HStack(alignment: .top, spacing: 8) {
                        input("\(value.label) \(value.money.currency.code) amount", key: "amount.\(value.id)", placeholder: "0", currency: value.money.currency.code,
                              binding: Binding(get: { viewModel.amountInputText("amount.\(value.id)") }, set: { viewModel.editCommitment(region: region, id: value.id, field: "amount", text: $0) }))
                            .frame(width: amountWidth)
                        billDateButton(value, region: region)
                        Button { billDetailsID = value.id } label: { Image(systemName: "ellipsis") }
                            .lfIconAction().accessibilityLabel("Details for \(value.label)")
                            .popover(isPresented: Binding(get: { billDetailsID == value.id }, set: { if !$0 { billDetailsID = nil } })) {
                                billDetails(value, region: region).padding(20).frame(width: 450)
                            }
                    }
                }
                if let due = viewModel.plan.dueDate(for: value), let cycle = viewModel.plan.assistance?.salaryCycle, due < cycle.recurringStart {
                    Text("Due before payday · review payment status in Plan insights")
                        .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                }
            }
            Button { viewModel.addCommitment(region: region) } label: { Label("Add bill", systemImage: "plus") }.lfSecondaryAction()
        }
    }

    private func billDetails(_ value: FundingPlanCommitment, region: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(value.label.isEmpty ? "Bill details" : value.label).font(theme.typography.sectionTitle)
            Toggle("This month only", isOn: Binding(get: { !value.recurs }, set: { viewModel.setCommitmentDetails(region: region, id: value.id, recurs: !$0) }))
            if value.recurs {
                Toggle("Reduced for this month only", isOn: Binding(get: { value.temporaryCarryBasis != nil }, set: { viewModel.setCommitmentDetails(region: region, id: value.id, temporary: $0) }))
                Text(value.temporaryCarryBasis.map { "Next month retains \(MoneyFormatting.display($0))." } ?? "Use this after part of a bill is paid. Next month keeps the full amount.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            TextField("Day / remark (optional)", text: Binding(get: { value.remark }, set: { viewModel.setCommitmentDetails(region: region, id: value.id, remark: $0) })).lfTextField()
            if viewModel.isConfirmedRecurringRow(value.id) {
                Text("Funding account").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                LFAccountLabel(title: value.fundingAccountID.map(viewModel.retainedCommitmentAccountLabel) ?? "Unavailable",
                    detail: value.fundingAccountID.map(viewModel.retainedCommitmentAccountContext) ?? "")
            } else {
                let cards = viewModel.eligibleCommitmentAccounts.filter { $0.nativeCurrency.code == value.money.currency.code }
                let cardOptions = cards.map { LFAccountMenu.Option(id: $0.repositoryAccountId ?? "", title: $0.preferredDisplayName, detail: $0.selectionContext) }
                let retainedOption = value.fundingAccountID.flatMap { id in
                    cards.contains { $0.repositoryAccountId == id } ? nil
                        : LFAccountMenu.Option(id: id, title: viewModel.retainedCommitmentAccountLabel(id: id), detail: viewModel.retainedCommitmentAccountContext(id: id))
                }
                LFAccountPicker(label: "Related card", placeholder: "None",
                    selection: Binding(get: { value.fundingAccountID ?? "" }, set: { viewModel.editCommitment(region: region, id: value.id, field: "account", text: $0) }),
                    options: cardOptions + (retainedOption.map { [$0] } ?? []))
                Text(viewModel.provenanceText(value.provenance)).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Button("Review funding and payments") { billDetailsID = nil; viewModel.insightSelection.section = "Commitments"; section = "Plan insights" }.lfSecondaryAction()
            HStack {
                Button("Remove bill", role: .destructive) { billDetailsID = nil; viewModel.removeCommitment(region: region, id: value.id) }.lfSecondaryAction()
                Spacer()
                Button("Done") { billDetailsID = nil }.lfPrimaryAction()
            }
        }.font(theme.typography.body)
    }

    private func billDateButton(_ row: FundingPlanCommitment, region: String) -> some View {
        Button {
            billDateSelection = viewModel.billDatePickerValue(for: row)
            billDateRowID = row.id
        } label: {
            Label(viewModel.plan.dueDate(for: row)?.presentation ?? "No date", systemImage: "calendar")
                .font(theme.typography.secondary).fixedSize().padding(.vertical, 5)
        }
        .lfIconAction().foregroundStyle(theme.palette.primaryText)
        .accessibilityLabel("Due date for \(row.label)").accessibilityValue(viewModel.plan.dueDate(for: row)?.presentation ?? "No date")
        .popover(isPresented: Binding(get: { billDateRowID == row.id }, set: { if !$0 { billDateRowID = nil } })) {
            VStack(alignment: .leading, spacing: 12) {
                Group {
                    if let range = viewModel.billDateRange(for: row.id) {
                        DatePicker("Due date this cycle", selection: $billDateSelection, in: range, displayedComponents: .date)
                    } else {
                        DatePicker("First due date", selection: $billDateSelection, displayedComponents: .date)
                    }
                }.datePickerStyle(.graphical).environment(\.calendar, Calendar(identifier: .gregorian))
                Text(viewModel.isConfirmedRecurringRow(row.id)
                     ? "Applies to this cycle only. The recurring schedule stays unchanged."
                     : "Repeats on this day each month. Shorter months use their last day.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                HStack {
                    Button("Remove date") { viewModel.setBillDate(region: region, id: row.id, date: nil); billDateRowID = nil }
                        .lfSecondaryAction().disabled(row.dueDate == nil || viewModel.isConfirmedRecurringRow(row.id))
                    Spacer()
                    Button("Cancel") { billDateRowID = nil }.lfSecondaryAction().keyboardShortcut(.cancelAction)
                    Button("Use date") { viewModel.setBillDate(region: region, id: row.id, date: billDateSelection); billDateRowID = nil }
                        .lfPrimaryAction().keyboardShortcut(.defaultAction)
                }
            }.padding().frame(width: max(380, theme.typography.size(.button) * 28))
        }
    }

    private func display(_ money: Money?) -> String {
        viewModel.hasValidCalculation ? money.map { MoneyFormatting.display($0) } ?? "Unavailable" : "Incomplete"
    }

    private var manualFXObservationDate: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                fxDateSelection = viewModel.manualFXPickerDate()
                showingFXDatePicker = true
            } label: {
                HStack {
                    Text(viewModel.manualFXObservationDateTitle)
                    Spacer()
                    Image(systemName: "calendar")
                }.contentShape(Rectangle())
            }
            .buttonStyle(LFPlainActionStyle()).lfTextField()
            .accessibilityLabel("Observed date").accessibilityValue(viewModel.rawText["fx.date"] ?? "Not selected")
            .accessibilityIdentifier("planner.fx.date")
            .popover(isPresented: $showingFXDatePicker) {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Observed date", selection: $fxDateSelection, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                    HStack {
                        Button("Clear") {
                            viewModel.setFX(rateText: viewModel.rawText["fx.rate"] ?? "", dateText: "")
                            showingFXDatePicker = false
                        }.lfSecondaryAction().disabled((viewModel.rawText["fx.date"] ?? "").isEmpty)
                        Spacer()
                        Button("Cancel") { showingFXDatePicker = false }.lfSecondaryAction().keyboardShortcut(.cancelAction)
                        Button("Use date") {
                            viewModel.setManualFXObservationDate(fxDateSelection)
                            showingFXDatePicker = false
                        }.lfPrimaryAction().keyboardShortcut(.defaultAction)
                    }
                }.padding().frame(width: max(380, theme.typography.size(.button) * 28))
            }
            if let error = viewModel.fieldErrors["fx.date"] {
                Text(error).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func moneyInput(_ label: String, _ field: SalaryWorkspaceViewModel.MoneyField, _ provenance: FundingPlanValueProvenance) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(label); Spacer(); Text("QAR").foregroundStyle(theme.palette.secondaryText)
                input(label, key: field.rawValue, placeholder: "0", currency: "QAR", binding: Binding(
                    get: { viewModel.amountInputText(field.rawValue) },
                    set: { _ = viewModel.updateMoney(field, text: $0) }
                )).frame(maxWidth: 150)
            }
            Text(viewModel.provenanceText(provenance)).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func valueRow(_ label: String, _ money: Money?, truth: String) -> some View {
        textValueRow(label, (section == "Salary History" || viewModel.hasValidCalculation) ? money.map { MoneyFormatting.display($0) } ?? "Incomplete" : "Incomplete", truth: truth)
    }

    private func textValueRow(_ label: String, _ value: String, truth: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.valueGutter) {
                VStack(alignment: .leading, spacing: 2) { Text(label); if !truth.isEmpty { Text(truth).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) } }
                Spacer(minLength: 0)
                Text(value).font(theme.typography.font(.body, tabularDigits: true).weight(.semibold)).fixedSize()
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(label)
                LFCompleteValue(lineHeight: theme.typography.lineHeight(.formBody)) {
                    Text(value).font(theme.typography.font(.body, tabularDigits: true).weight(.semibold))
                }
                if !truth.isEmpty { Text(truth).font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText) }
            }
        }
        .foregroundStyle(value == "Incomplete" ? LFTheme.warning : theme.palette.primaryText)
    }
}
