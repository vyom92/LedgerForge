import SwiftUI

struct SalaryView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var viewModel: SalaryWorkspaceViewModel
    @ObservedObject private var salaryStore: SalaryStore = .shared
    @State private var section = "This Month"
    @State private var confirmingCopy = false
    @State private var confirmingDiscard = false
    @State private var showingFXDatePicker = false
    @State private var fxDateSelection = Date()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Salary section", selection: $section) {
                        Text(viewModel.planMonthTitle).tag("This Month")
                        Text("Salary History").tag("Salary History")
                    }.pickerStyle(.segmented).frame(maxWidth: 380)
                    if section == "This Month" {
                        header
                        if let error = viewModel.errorMessage { Text(error).font(theme.typography.formCallout).foregroundStyle(LFTheme.warning).textSelection(.enabled) }
                        if geometry.size.width >= 850 {
                            HStack(alignment: .top, spacing: 16) {
                                qatarColumn.disabled(!viewModel.canEdit).frame(maxWidth: .infinity)
                                indiaColumn.disabled(!viewModel.canEdit).frame(maxWidth: .infinity)
                            }
                        } else { qatarColumn.disabled(!viewModel.canEdit); indiaColumn.disabled(!viewModel.canEdit) }
                        results
                    } else { history }
                }.padding(theme.spacing.pagePadding)
            }
        }
        .confirmationDialog("Discard unsaved changes and copy the previous plan?", isPresented: $confirmingCopy, titleVisibility: .visible) {
            Button("Discard and copy", role: .destructive) { viewModel.rolloverFromPreviousPlan(discardingDraft: true) }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Discard this draft and reload the current database?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard and reload", role: .destructive) { viewModel.discardAndReload() }
            Button("Keep draft", role: .cancel) {}
        }
        .onAppear { viewModel.refreshCapturedAccountBalances() }
        .onDisappear { viewModel.cancelAlDarRefresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Funding plan · \(viewModel.planMonthTitle)").font(theme.typography.formTitle.weight(.semibold))
                    Text(viewModel.statusText).font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Button("Copy previous month") {
                    if viewModel.isDirty { confirmingCopy = true } else { viewModel.rolloverFromPreviousPlan() }
                }.disabled(!viewModel.canRollover || !viewModel.canEdit)
                Button("Save") { viewModel.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent).disabled(!viewModel.canEdit)
            }
            if viewModel.saveState == .committedNeedsRefresh {
                Button("Reload saved plan") { viewModel.retryCanonicalRefresh() }
            } else if viewModel.saveState == .providerChanged || viewModel.saveState == .canonicalChanged || viewModel.saveState == .committedToPreviousProvider {
                Button("Discard draft and reload") { confirmingDiscard = true }
            }
        }
    }

    private var qatarColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Qatar · QAR").font(theme.typography.formSection.weight(.semibold))
            LFPanel(title: "Expected salary") {
                VStack(spacing: 12) {
                    moneyInput("Fixed earnings", .fixed, viewModel.plan.expectedFixedProvenance)
                    moneyInput("Variable earnings", .variable, viewModel.plan.expectedVariableProvenance)
                    moneyInput("Deductions", .deductions, viewModel.plan.expectedDeductionsProvenance)
                    Divider()
                    valueRow("Expected net", viewModel.calculation.expectedNet, truth: "Calculated")
                    textValueRow("Salary actuals", viewModel.currentMonthActual.map { MoneyFormatting.display($0) } ?? "No payslip for this month", truth: "Total from payslips")
                }
            }
            balances(currency: "QAR")
            commitments(title: "Qatar commitments", region: "qatar", values: viewModel.plan.qatarCommitments)
        }
    }

    private var indiaColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("India · INR").font(theme.typography.formSection.weight(.semibold))
            balances(currency: "INR")
            commitments(title: "India commitments", region: "india", values: viewModel.plan.indiaCommitments)
            LFPanel(title: "Transfer planning") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Planning rate (INR per QAR)").font(theme.typography.formBody)
                    input("INR per QAR", key: "fx.rate", binding: Binding(get: { viewModel.rawText["fx.rate"] ?? "" }, set: { viewModel.setFX(rateText: $0, dateText: viewModel.rawText["fx.date"] ?? "") }))
                    manualFXObservationDate
                    Text("Your planning rate · used only for \(viewModel.planMonthTitle)").font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                    Divider()
                    alDarReference
                    Divider()
                    moneyInput("Transfer fee", .fee, viewModel.plan.configuredTransferFeeProvenance)
                    moneyInput("Planned investment", .investment, viewModel.plan.plannedInvestmentProvenance)
                }
            }
        }
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
            .buttonStyle(.plain).lfTextField()
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
                        }.disabled((viewModel.rawText["fx.date"] ?? "").isEmpty)
                        Spacer()
                        Button("Cancel") { showingFXDatePicker = false }.keyboardShortcut(.cancelAction)
                        Button("Use date") {
                            viewModel.setManualFXObservationDate(fxDateSelection)
                            showingFXDatePicker = false
                        }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    }
                }.padding().frame(width: 310)
            }
            if let error = viewModel.fieldErrors["fx.date"] {
                Text(error).font(theme.typography.formCaption).foregroundStyle(LFTheme.warning)
            }
        }
    }

    private func moneyInput(_ label: String, _ field: SalaryWorkspaceViewModel.MoneyField, _ provenance: FundingPlanValueProvenance) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(label); Spacer(); Text("QAR").foregroundStyle(theme.palette.secondaryText)
                input(label, key: field.rawValue, placeholder: "0", binding: Binding(
                    get: { viewModel.amountInputText(field.rawValue) },
                    set: { _ = viewModel.updateMoney(field, text: $0) }
                )).frame(maxWidth: 150)
            }
            Text(viewModel.provenanceText(provenance)).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var alDarReference: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Al Dar reference").font(theme.typography.formHeading.weight(.semibold))
                Spacer()
                if viewModel.isRefreshingAlDar { ProgressView().controlSize(.small).accessibilityLabel("Refreshing Al Dar reference") }
                Button("Refresh Al Dar") { viewModel.startAlDarRefresh() }
                    .lfSecondaryAction().disabled(!viewModel.canRefreshAlDar)
                    .accessibilityIdentifier("planner.aldar.refresh")
            }
            Text(viewModel.alDarGuidance).font(theme.typography.formCaption)
                .foregroundStyle(theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            if let pending = viewModel.pendingAlDarReference {
                referenceDetails(pending, status: "Candidate · not applied")
                Button("Use Reference") { viewModel.useAlDarReference() }
                    .lfSecondaryAction().disabled(!viewModel.canUseAlDarReference)
                    .accessibilityIdentifier("planner.aldar.apply")
                if !viewModel.canUseAlDarReference {
                    Text(viewModel.alDarApplicationGuidance).font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let applied = viewModel.plan.alDarReference {
                referenceDetails(applied.quote, status: viewModel.isDirty ? "Selected reference · draft" : "Reference used by saved plan")
                if applied.quote.submittedQAR.amount != 1, viewModel.hasValidCalculation,
                   let principal = viewModel.calculation.requiredQARPrincipal, principal != applied.quote.submittedQAR {
                    LFInfoRow(title: "Current estimate after applying reference", value: MoneyFormatting.display(principal))
                    Text("Estimated using this saved reference. A new lookup uses QAR 1.")
                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if viewModel.pendingAlDarReference == nil, let previous = viewModel.previousAlDarContext {
                referenceDetails(previous.quote, status: "Previous reference · not applied")
            }
        }
    }

    private func referenceDetails(_ quote: AlDarReferenceQuote, status: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(status).font(theme.typography.formCaption.weight(.medium))
            if quote.submittedQAR.amount == 1 {
                LFInfoRow(title: "Rate", value: "1 QAR = \(quote.displayRate) INR")
            } else {
                LFInfoRow(title: "Reference requested for", value: MoneyFormatting.display(quote.submittedQAR))
                LFInfoRow(title: "Returned INR · exact", value: quote.returnedINR.rawToken)
                Text("Approx. \(quote.displayRate) INR per QAR · display only")
                    .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            }
            Text("Al Dar · QAR → INR · indicative reference")
                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            Text("Fetched \(ImportInstantFormatting.display(quote.fetchedAtISO))")
                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
        }.textSelection(.enabled)
    }

    private func input(_ title: String, key: String, placeholder: String? = nil, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(title, text: binding, prompt: Text(placeholder ?? title)).lfTextField()
                .accessibilityLabel(title).accessibilityIdentifier("planner." + key)
            if let error = viewModel.fieldErrors[key] { Text(error).font(theme.typography.formCaption).foregroundStyle(LFTheme.warning).fixedSize(horizontal: false, vertical: true) }
        }
    }

    private func balances(currency: String) -> some View {
        LFPanel(title: "Balances to include") {
            VStack(alignment: .leading, spacing: 12) {
                let accounts = viewModel.eligibleAccounts.filter { $0.nativeCurrency.code == currency }
                if accounts.isEmpty { Text("No eligible \(currency) accounts. Select balances explicitly when available.").font(theme.typography.formCallout).foregroundStyle(theme.palette.secondaryText) }
                ForEach(accounts, id: \.id) { account in
                    let balance = viewModel.plan.balances.first { $0.accountID == account.repositoryAccountId }
                    let key = "balance.\(account.repositoryAccountId ?? "")"
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle(account.nickname ?? account.name, isOn: Binding(get: { balance?.included ?? false }, set: { viewModel.setAccountIncluded(account, included: $0) }))
                        HStack {
                            input("Planning balance", key: key, placeholder: "0", binding: Binding(get: { viewModel.amountInputText(key) }, set: { viewModel.setManualBalance(account, text: $0) }))
                            Button("Capture current") { viewModel.captureAccountBalance(account) }
                                .lfSecondaryAction()
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        Text(balance.map { viewModel.provenanceText($0.provenance) } ?? "No planning balance").font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
                        if viewModel.unavailableCurrentBalanceAccountIDs.contains(account.repositoryAccountId ?? "") {
                            Text(balance?.money == nil
                                 ? "Current balance unavailable. Enter a planning balance manually."
                                 : "Could not refresh the current balance. Keeping your existing planning value.")
                                .font(theme.typography.formCaption)
                                .foregroundStyle(LFTheme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                ForEach(viewModel.plan.balances.filter { balance in balance.nativeCurrency.code == currency && !accounts.contains(where: { $0.repositoryAccountId == balance.accountID }) }) { balance in
                    Text("Saved account is no longer eligible · \(balance.included ? "included" : "excluded") · \(balance.money.map { MoneyFormatting.display($0) } ?? "Balance unavailable")")
                        .font(theme.typography.font(.formCaption, tabularDigits: true)).foregroundStyle(LFTheme.warning)
                }
            }
        }
    }

    private func commitments(title: String, region: String, values: [FundingPlanCommitment]) -> some View {
        LFPanel(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(values) { value in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Toggle("Include", isOn: Binding(get: { value.included }, set: { update(value, region: region, included: $0) })).labelsHidden().accessibilityLabel("Include commitment")
                            input("Commitment", key: "label.\(value.id)", binding: Binding(get: { viewModel.rawText["label.\(value.id)"] ?? value.label }, set: { update(value, region: region, label: $0) }))
                            Button(role: .destructive) { viewModel.removeCommitment(region: region, id: value.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel("Remove commitment").help("Remove commitment")
                        }
                        HStack {
                            Text(region == "qatar" ? "QAR" : "INR")
                            input("Amount", key: "amount.\(value.id)", placeholder: "0", binding: Binding(get: { viewModel.amountInputText("amount.\(value.id)") }, set: { update(value, region: region, amount: $0) }))
                        }
                        let cards = viewModel.eligibleCommitmentAccounts.filter { $0.nativeCurrency.code == value.money.currency.code }
                        Picker("Credit card", selection: Binding(get: { value.fundingAccountID ?? "" }, set: { update(value, region: region, account: $0) })) {
                            Text("Unassigned").tag("")
                            ForEach(cards, id: \.id) { Text($0.nickname ?? $0.name).tag($0.repositoryAccountId ?? "") }
                            if let savedID = value.fundingAccountID, !cards.contains(where: { $0.repositoryAccountId == savedID }) {
                                Text(viewModel.retainedCommitmentAccountLabel(id: savedID)).tag(savedID)
                            }
                        }
                        Text(viewModel.provenanceText(value.provenance)).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
                    }
                    Divider()
                }
                Button { viewModel.addCommitment(region: region) } label: { Label("Add commitment", systemImage: "plus") }
                    .lfSecondaryAction()
            }
        }
    }

    private func update(_ value: FundingPlanCommitment, region: String, label: String? = nil, amount: String? = nil, included: Bool? = nil, account: String? = nil) {
        let field: String; let text: String
        if let label { field = "label"; text = label }
        else if let amount { field = "amount"; text = amount }
        else if let included { field = "included"; text = String(included) }
        else if let account { field = "account"; text = account }
        else { return }
        viewModel.editCommitment(region: region, id: value.id, field: field, text: text)
    }

    private var results: some View {
        LFPanel(title: "Funding position · Calculated") {
            VStack(spacing: 10) {
                valueRow("Selected QAR liquidity", viewModel.calculation.selectedQARLiquidity, truth: "Included planning balances")
                valueRow("Selected INR liquidity", viewModel.calculation.selectedINRLiquidity, truth: "Included planning balances")
                valueRow("India funding shortfall", viewModel.calculation.indiaFundingShortfall, truth: "After included INR liquidity")
                valueRow("Required QAR principal", viewModel.calculation.requiredQARPrincipal, truth: viewModel.plan.alDarReference == nil ? "Using this plan’s dated FX rate" : "Using this plan’s Al Dar reference")
                valueRow("Effective transfer fee", viewModel.calculation.effectiveTransferFee, truth: "Zero when no transfer is required")
                valueRow("Available for investment", viewModel.calculation.availableForInvestment, truth: "After commitments and transfer")
                valueRow("Final QAR buffer", viewModel.calculation.finalQARBuffer, truth: "After planned investment")
                if !viewModel.hasValidCalculation { Text("Correct the marked inputs to calculate this plan.").foregroundStyle(LFTheme.warning) }
                if viewModel.calculation.incompleteReasons.contains(.missingPlanningFX) { Text("Add a dated FX rate to calculate the India transfer.").foregroundStyle(LFTheme.warning) }
                if viewModel.calculation.incompleteReasons.contains(.invalidPlanningReference) { Text("The selected reference cannot calculate this transfer. Refresh or enter a manual rate.").foregroundStyle(LFTheme.warning) }
                if viewModel.calculation.incompleteReasons.contains(.includedQARBalanceMissing) || viewModel.calculation.incompleteReasons.contains(.includedINRBalanceMissing) { Text("An included account needs a planning balance.").foregroundStyle(LFTheme.warning) }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Salary History").font(theme.typography.formTitle.weight(.semibold))
            if salaryStore.statements.isEmpty {
                LFPanel(title: "From payslip") {
                    Text("No accepted Qatar Airways salary statements.").foregroundStyle(theme.palette.secondaryText)
                }
            }
            ForEach(viewModel.historyGroups, id: \.month) { group in
                LFPanel(title: SalaryWorkspaceViewModel.monthTitle(group.month)) {
                    textValueRow("Salary actuals", MoneyFormatting.display(group.actual), truth: "Total from payslips")
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(group.statements) { statement in
                            DisclosureGroup {
                                salaryStatementDetail(statement)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(statement.evidence.kind.displayName).font(theme.typography.formHeading)
                                        Text("Pay period \(SalaryWorkspaceViewModel.monthTitle(statement.evidence.financialPeriod)) · Print date \(statement.evidence.printDate?.canonical ?? "Not printed")")
                                            .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                                    }
                                    Spacer()
                                    Text(MoneyFormatting.display(statement.evidence.printedPaymentTotal)).font(theme.typography.font(.formHeading, tabularDigits: true))
                                }
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func salaryStatementDetail(_ statement: SalaryStatement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From payslip").font(theme.typography.formCaption.weight(.semibold)).foregroundStyle(LFTheme.info)
            Text("Qatar Airways")
                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            Text("Earnings").font(theme.typography.formBody.weight(.semibold))
            ForEach(statement.evidence.earnings, id: \.sourceOrdinal) { component in
                LFInfoRow(title: "\(component.sourceOrdinal). \(component.sourceLabel)", value: MoneyFormatting.display(component.money), textRole: .formBody)
                    .monospacedDigit()
            }
            Text("Deductions").font(theme.typography.formBody.weight(.semibold))
            if statement.evidence.printedDeductionsTotal == nil {
                Text("No deduction section or total printed in source").foregroundStyle(theme.palette.secondaryText)
            } else {
                ForEach(statement.evidence.deductions, id: \.sourceOrdinal) { component in
                    LFInfoRow(title: "\(component.sourceOrdinal). \(component.sourceLabel)", value: MoneyFormatting.display(component.money), textRole: .formBody)
                        .monospacedDigit()
                }
            }
            Divider()
            valueRow("Printed earnings", statement.evidence.printedEarningsTotal, truth: "From payslip")
            if let deductions = statement.evidence.printedDeductionsTotal { valueRow("Printed deductions", deductions, truth: "From payslip") }
            valueRow("Printed net", statement.evidence.printedNet, truth: "From payslip")
            valueRow("Printed payment total", statement.evidence.printedPaymentTotal, truth: "From payslip")
        }.padding(.top, 8)
    }

    private func valueRow(_ label: String, _ money: Money?, truth: String) -> some View {
        textValueRow(label, (section == "Salary History" || viewModel.hasValidCalculation) ? money.map { MoneyFormatting.display($0) } ?? "Incomplete" : "Incomplete", truth: truth)
    }

    private func textValueRow(_ label: String, _ value: String, truth: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: theme.spacing.valueGutter) {
                VStack(alignment: .leading, spacing: 2) { Text(label); Text(truth).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText) }
                Spacer(minLength: 0)
                Text(value).font(theme.typography.font(.formBody, tabularDigits: true).weight(.semibold)).fixedSize()
            }
            VStack(alignment: .leading, spacing: theme.spacing.micro) {
                Text(label)
                LFCompleteValue(lineHeight: theme.typography.lineHeight(.formBody)) {
                    Text(value).font(theme.typography.font(.formBody, tabularDigits: true).weight(.semibold))
                }
                Text(truth).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
            }
        }
        .foregroundStyle(value == "Incomplete" ? LFTheme.warning : theme.palette.primaryText)
    }
}
