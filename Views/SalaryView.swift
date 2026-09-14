import SwiftUI

struct SalaryView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var viewModel: SalaryWorkspaceViewModel
    @ObservedObject private var salaryStore: SalaryStore = .shared
    @State private var section = "This Month"
    @State private var confirmingCopy = false
    @State private var confirmingDiscard = false
    @State private var editedMoneyFields: Set<String> = []

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Salary section", selection: $section) {
                        Text("This Month").tag("This Month")
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
        .onChange(of: viewModel.plan.id) { _, _ in editedMoneyFields.removeAll() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Funding plan · \(viewModel.plan.month.canonical)").font(theme.typography.formTitle.weight(.semibold))
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
                    textValueRow("Salary received", viewModel.currentMonthActual.map { MoneyFormatting.display($0) } ?? "No payslip for this month", truth: "Total from payslips")
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
                    Text("1 QAR = INR per QAR").font(theme.typography.formBody)
                    input("INR per QAR", key: "fx.rate", binding: Binding(get: { viewModel.rawText["fx.rate"] ?? "" }, set: { viewModel.setFX(rateText: $0, dateText: viewModel.rawText["fx.date"] ?? "") }))
                    input("Observed YYYY-MM-DD", key: "fx.date", binding: Binding(get: { viewModel.rawText["fx.date"] ?? "" }, set: { viewModel.setFX(rateText: viewModel.rawText["fx.rate"] ?? "", dateText: $0) }))
                    Text("Your planning rate · used only for this month’s transfer").font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                    moneyInput("Transfer fee", .fee, viewModel.plan.configuredTransferFeeProvenance)
                    moneyInput("Planned investment", .investment, viewModel.plan.plannedInvestmentProvenance)
                }
            }
        }
    }

    private func moneyInput(_ label: String, _ field: SalaryWorkspaceViewModel.MoneyField, _ provenance: FundingPlanValueProvenance) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(label); Spacer(); Text("QAR").foregroundStyle(theme.palette.secondaryText)
                input(label, key: field.rawValue, binding: Binding(
                    get: {
                        !editedMoneyFields.contains(field.rawValue) && viewModel.isInitialZeroInput(field)
                            ? "" : viewModel.moneyText(field)
                    },
                    set: {
                        editedMoneyFields.insert(field.rawValue)
                        _ = viewModel.updateMoney(field, text: $0)
                    }
                )).frame(maxWidth: 150)
            }
            Text(viewModel.provenanceText(provenance)).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func input(_ title: String, key: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            TextField(title, text: binding).lfTextField().accessibilityIdentifier("planner." + key)
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
                            input("Planning balance", key: key, binding: Binding(get: { viewModel.rawText[key] ?? "" }, set: { viewModel.setManualBalance(account, text: $0) }))
                            Button("Capture current") { viewModel.captureAccountBalance(account) }
                        }
                        Text(balance.map { viewModel.provenanceText($0.provenance) } ?? "No planning balance").font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText)
                    }
                }
                ForEach(viewModel.plan.balances.filter { balance in balance.nativeCurrency.code == currency && !accounts.contains(where: { $0.repositoryAccountId == balance.accountID }) }) { balance in
                    Text("Saved account is no longer eligible · \(balance.included ? "included" : "excluded") · \(balance.money.map { MoneyFormatting.display($0) } ?? "Balance unavailable")")
                        .font(theme.typography.formCaption).foregroundStyle(LFTheme.warning)
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
                            Button(role: .destructive) { viewModel.removeCommitment(region: region, id: value.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel("Remove commitment")
                        }
                        HStack {
                            Text(region == "qatar" ? "QAR" : "INR")
                            input("Amount", key: "amount.\(value.id)", binding: Binding(get: { viewModel.rawText["amount.\(value.id)"] ?? "" }, set: { update(value, region: region, amount: $0) }))
                        }
                        Picker("Funding account", selection: Binding(get: { value.fundingAccountID ?? "" }, set: { update(value, region: region, account: $0) })) {
                            Text("Unassigned").tag("")
                            ForEach(viewModel.eligibleAccounts.filter { $0.nativeCurrency.code == value.money.currency.code }, id: \.id) { Text($0.nickname ?? $0.name).tag($0.repositoryAccountId ?? "") }
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
                valueRow("Required QAR principal", viewModel.calculation.requiredQARPrincipal, truth: "Using this plan’s dated FX rate")
                valueRow("Effective transfer fee", viewModel.calculation.effectiveTransferFee, truth: "Zero when no transfer is required")
                valueRow("Available for investment", viewModel.calculation.availableForInvestment, truth: "After commitments and transfer")
                valueRow("Final QAR buffer", viewModel.calculation.finalQARBuffer, truth: "After planned investment")
                if !viewModel.hasValidCalculation { Text("Correct the marked inputs to calculate this plan.").foregroundStyle(LFTheme.warning) }
                if viewModel.calculation.incompleteReasons.contains(.missingPlanningFX) { Text("Add a dated FX rate to calculate the India transfer.").foregroundStyle(LFTheme.warning) }
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
                LFPanel(title: "\(group.month.canonical) · Total from payslips \(MoneyFormatting.display(group.actual))") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(group.statements) { statement in
                            DisclosureGroup {
                                salaryStatementDetail(statement)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(statement.evidence.kind.displayName).font(theme.typography.formHeading)
                                        Text("Pay period \(statement.evidence.financialPeriod.canonical) · Print date \(statement.evidence.printDate?.canonical ?? "Not printed")")
                                            .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                                    }
                                    Spacer()
                                    Text(MoneyFormatting.display(statement.evidence.printedPaymentTotal)).font(theme.typography.formHeading)
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
                HStack { Text("\(component.sourceOrdinal). \(component.sourceLabel)"); Spacer(); Text(MoneyFormatting.display(component.money)) }
            }
            Text("Deductions").font(theme.typography.formBody.weight(.semibold))
            if statement.evidence.printedDeductionsTotal == nil {
                Text("No deduction section or total printed in source").foregroundStyle(theme.palette.secondaryText)
            } else {
                ForEach(statement.evidence.deductions, id: \.sourceOrdinal) { component in
                    HStack { Text("\(component.sourceOrdinal). \(component.sourceLabel)"); Spacer(); Text(MoneyFormatting.display(component.money)) }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) { Text(label); Text(truth).font(theme.typography.finePrint).foregroundStyle(theme.palette.secondaryText) }
            Spacer(); Text(value).font(theme.typography.formBody.weight(.semibold)).foregroundStyle(value == "Incomplete" ? LFTheme.warning : theme.palette.primaryText)
        }
    }
}
