import SwiftUI

struct SalaryView: View {
    @StateObject private var viewModel = SalaryWorkspaceViewModel()
    @ObservedObject private var salaryStore: SalaryStore = .shared
    @ObservedObject private var fundingPlanStore: FundingPlanStore = .shared
    @State private var fxRate = ""
    @State private var fxDate = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                truthLegend
                thisMonth
                history
            }
            .padding(28)
        }
        .onAppear { syncFX() }
        .onChange(of: fundingPlanStore.plans) { _, _ in syncFX() }
        .alert("Salary workspace", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )) { Button("OK", role: .cancel) { viewModel.dismissError() } } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var truthLegend: some View {
        LFPanel(title: "Truth classes") {
            HStack(spacing: 12) {
                truthChip("Imported Source Truth", icon: "doc.text.magnifyingglass")
                truthChip("Account Snapshot", icon: "camera")
                truthChip("User / Carried Input", icon: "pencil.and.list.clipboard")
                truthChip("Derived Result", icon: "function")
            }
        }
    }

    private var thisMonth: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("This Month")
                        .font(.title2.weight(.semibold))
                    Text("Current-month funding plan · \(viewModel.plan.month.canonical)")
                        .foregroundStyle(LFTheme.textSecondary)
                }
                Spacer()
                Button("Roll Over Previous Plan") { viewModel.rolloverFromPreviousPlan(); syncFX() }
                    .buttonStyle(.bordered)
                Button("Save Plan") { applyFX(); viewModel.save() }
                    .buttonStyle(.borderedProminent)
            }

            HStack(alignment: .top, spacing: 14) {
                salaryInputs
                results
            }
            balances
            commitments(title: "Qatar commitments", region: "qatar", values: viewModel.plan.qatarCommitments)
            commitments(title: "India commitments", region: "india", values: viewModel.plan.indiaCommitments)
            fxAndFee
        }
    }

    private var salaryInputs: some View {
        LFPanel(title: "Expected salary · User / Carried Input") {
            VStack(spacing: 10) {
                MoneyInputRow(label: "Expected fixed earnings", currency: "QAR", initial: viewModel.moneyText(.fixed)) { _ = viewModel.updateMoney(.fixed, text: $0) }
                MoneyInputRow(label: "Expected variable earnings", currency: "QAR", initial: viewModel.moneyText(.variable)) { _ = viewModel.updateMoney(.variable, text: $0) }
                MoneyInputRow(label: "Expected deductions", currency: "QAR", initial: viewModel.moneyText(.deductions)) { _ = viewModel.updateMoney(.deductions, text: $0) }
                Divider()
                valueRow("Expected net", viewModel.calculation.expectedNet, truth: "Derived Result")
                if let actual = viewModel.currentMonthActual {
                    valueRow("Actual salary this month", actual, truth: "Imported Source Truth · derived monthly aggregate")
                } else {
                    textValueRow("Actual salary this month", "No accepted salary actual", truth: "Imported Source Truth")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var results: some View {
        LFPanel(title: "Funding position · Derived Result") {
            VStack(spacing: 10) {
                valueRow("Selected QAR liquidity", viewModel.calculation.selectedQARLiquidity, truth: "Account Snapshot")
                valueRow("Selected INR liquidity", viewModel.calculation.selectedINRLiquidity, truth: "Account Snapshot")
                valueRow("INR commitments", viewModel.calculation.indiaCommitments, truth: "Derived from included input")
                valueRow("India funding shortfall", viewModel.calculation.indiaFundingShortfall, truth: "Derived Result")
                valueRow("Required QAR principal", viewModel.calculation.requiredQARPrincipal, truth: fxContext)
                valueRow("Effective transfer fee", viewModel.calculation.effectiveTransferFee, truth: "Derived Result")
                valueRow("Available for investment", viewModel.calculation.availableForInvestment, truth: "Derived Result")
                valueRow("Final QAR buffer", viewModel.calculation.finalQARBuffer, truth: "Derived Result")
                if !viewModel.calculation.incompleteReasons.isEmpty {
                    Text("Incomplete: \(viewModel.calculation.incompleteReasons.map(\.rawValue).sorted().joined(separator: ", "))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LFTheme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var balances: some View {
        LFPanel(title: "Balances to consider · Account Snapshot") {
            VStack(spacing: 10) {
                if viewModel.eligibleAccounts.isEmpty {
                    Text("No eligible CBQ QAR or Axis/HDFC NRE/NRO INR accounts are available. Accounts are never selected automatically.")
                        .foregroundStyle(LFTheme.textSecondary)
                }
                ForEach(viewModel.eligibleAccounts, id: \.id) { account in
                    let saved = viewModel.plan.balances.first { $0.accountID == account.repositoryAccountId }
                    BalancePlanningRow(
                        account: account,
                        balance: saved,
                        onIncluded: { viewModel.setAccountIncluded(account, included: $0) },
                        onCapture: { viewModel.captureAccountBalance(account) },
                        onManual: { viewModel.setManualBalance(account, text: $0) }
                    )
                }
            }
        }
    }

    private func commitments(title: String, region: String, values: [FundingPlanCommitment]) -> some View {
        LFPanel(title: "\(title) · User / Carried Input") {
            VStack(spacing: 10) {
                ForEach(values) { value in
                    CommitmentPlanningRow(
                        commitment: value,
                        currency: region == "qatar" ? "QAR" : "INR",
                        eligibleAccounts: viewModel.eligibleAccounts.filter { $0.nativeCurrency.code == (region == "qatar" ? "QAR" : "INR") },
                        onChange: { label, amount, included, account in
                            viewModel.updateCommitment(region: region, id: value.id, label: label, amountText: amount, included: included, fundingAccountID: account)
                        },
                        onDelete: { viewModel.removeCommitment(region: region, id: value.id) }
                    )
                }
                Button { viewModel.addCommitment(region: region) } label: {
                    Label("Add commitment", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var fxAndFee: some View {
        LFPanel(title: "India funding conversion · User Input") {
            VStack(spacing: 10) {
                HStack {
                    Text("1 QAR =")
                    TextField("INR per QAR", text: $fxRate).textFieldStyle(.roundedBorder)
                    Text("INR")
                    TextField("YYYY-MM-DD", text: $fxDate).textFieldStyle(.roundedBorder).frame(width: 130)
                    Button("Apply FX") { applyFX() }.buttonStyle(.bordered)
                }
                Text("Plan-local, user-entered rate. No network or global exchange-rate table is used.")
                    .font(.caption).foregroundStyle(LFTheme.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                MoneyInputRow(label: "Configured transfer fee", currency: "QAR", initial: viewModel.moneyText(.fee)) { _ = viewModel.updateMoney(.fee, text: $0) }
                valueRow("Effective transfer fee", viewModel.calculation.effectiveTransferFee, truth: "Derived Result · zero when India shortfall is zero")
                MoneyInputRow(label: "Planned investment", currency: "QAR", initial: viewModel.moneyText(.investment)) { _ = viewModel.updateMoney(.investment, text: $0) }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Salary History").font(.title2.weight(.semibold))
            if salaryStore.statements.isEmpty {
                LFPanel(title: "Imported Source Truth") {
                    Text("No accepted Qatar Airways salary statements.").foregroundStyle(LFTheme.textSecondary)
                }
            }
            ForEach(viewModel.historyGroups, id: \.month) { group in
                LFPanel(title: "\(group.month.canonical) · Derived monthly actual \(MoneyFormatting.display(group.actual))") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(group.statements) { statement in
                            DisclosureGroup {
                                salaryStatementDetail(statement)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(statement.evidence.kind.displayName).font(.headline)
                                        Text("Pay period \(statement.evidence.financialPeriod.canonical) · Print date \(statement.evidence.printDate?.canonical ?? "Not printed")")
                                            .font(.caption).foregroundStyle(LFTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text(MoneyFormatting.display(statement.evidence.printedPaymentTotal)).font(.headline)
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
            Text("Imported Source Truth").font(.caption.weight(.semibold)).foregroundStyle(LFTheme.info)
            Text("Qatar Airways · \(statement.evidence.profileID)@\(statement.evidence.profileVersion)")
                .font(.caption).foregroundStyle(LFTheme.textSecondary)
            Text("Earnings").font(.subheadline.weight(.semibold))
            ForEach(statement.evidence.earnings, id: \.sourceOrdinal) { component in
                HStack { Text("\(component.sourceOrdinal). \(component.sourceLabel)"); Spacer(); Text(MoneyFormatting.display(component.money)) }
            }
            Text("Deductions").font(.subheadline.weight(.semibold))
            if statement.evidence.printedDeductionsTotal == nil {
                Text("No deduction section or total printed in source").foregroundStyle(LFTheme.textSecondary)
            } else {
                ForEach(statement.evidence.deductions, id: \.sourceOrdinal) { component in
                    HStack { Text("\(component.sourceOrdinal). \(component.sourceLabel)"); Spacer(); Text(MoneyFormatting.display(component.money)) }
                }
            }
            Divider()
            valueRow("Printed earnings", statement.evidence.printedEarningsTotal, truth: "Imported Source Truth")
            if let deductions = statement.evidence.printedDeductionsTotal { valueRow("Printed deductions", deductions, truth: "Imported Source Truth") }
            valueRow("Printed net", statement.evidence.printedNet, truth: "Imported Source Truth")
            valueRow("Printed payment total", statement.evidence.printedPaymentTotal, truth: "Imported Source Truth")
        }.padding(.top, 8)
    }

    private var fxContext: String {
        guard let fx = viewModel.plan.planningFX else { return "Derived Result · FX unavailable" }
        return "Derived Result · 1 QAR = \(NSDecimalNumber(decimal: fx.inrPerQAR).stringValue) INR observed \(fx.observationDate.canonical)"
    }

    private func syncFX() {
        fxRate = viewModel.plan.planningFX.map { NSDecimalNumber(decimal: $0.inrPerQAR).stringValue } ?? ""
        fxDate = viewModel.plan.planningFX?.observationDate.canonical ?? ""
    }

    private func applyFX() { viewModel.setFX(rateText: fxRate, dateText: fxDate) }

    private func truthChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 7)
            .background(LFTheme.surfaceRaised).clipShape(Capsule())
    }

    private func valueRow(_ label: String, _ money: Money?, truth: String) -> some View {
        textValueRow(label, money.map { MoneyFormatting.display($0) } ?? "Incomplete / unavailable", truth: truth)
    }

    private func textValueRow(_ label: String, _ value: String, truth: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) { Text(label); Text(truth).font(.caption2).foregroundStyle(LFTheme.textSecondary) }
            Spacer(); Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(value.contains("Incomplete") ? LFTheme.warning : LFTheme.text)
        }
    }
}

private struct MoneyInputRow: View {
    let label: String
    let currency: String
    let initial: String
    let onCommit: (String) -> Void
    @State private var text: String

    init(label: String, currency: String, initial: String, onCommit: @escaping (String) -> Void) {
        self.label = label; self.currency = currency; self.initial = initial; self.onCommit = onCommit
        _text = State(initialValue: initial)
    }

    var body: some View {
        HStack { Text(label); Spacer(); Text(currency).foregroundStyle(LFTheme.textSecondary); TextField("0.00", text: $text).textFieldStyle(.roundedBorder).frame(width: 130).onSubmit { onCommit(text) } }
    }
}

private struct BalancePlanningRow: View {
    let account: Account
    let balance: FundingPlanBalance?
    let onIncluded: (Bool) -> Void
    let onCapture: () -> Void
    let onManual: (String) -> Void
    @State private var manual = ""

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(get: { balance?.included ?? false }, set: onIncluded)).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(account.nickname ?? account.name).font(.subheadline.weight(.semibold))
                Text("\(account.institution) · \(account.nativeCurrency.code) · \(provenanceText)").font(.caption).foregroundStyle(LFTheme.textSecondary)
            }
            Spacer()
            Text(balance?.money.map { MoneyFormatting.display($0) } ?? "Balance unavailable").foregroundStyle(balance?.money == nil ? LFTheme.warning : LFTheme.text)
            TextField("Manual", text: $manual).textFieldStyle(.roundedBorder).frame(width: 110).onSubmit { onManual(manual) }
            Button("Capture current") { onCapture() }.buttonStyle(.bordered)
        }
    }

    private var provenanceText: String {
        guard let value = balance?.provenance else { return "No planning snapshot" }
        switch value { case .manual: return "Manual planning balance"; case .carried: return "Carried value"; case .capturedAccountBalance(let time): return "Captured \(time)" }
    }
}

private struct CommitmentPlanningRow: View {
    let commitment: FundingPlanCommitment
    let currency: String
    let eligibleAccounts: [Account]
    let onChange: (String, String, Bool, String?) -> Void
    let onDelete: () -> Void
    @State private var label: String
    @State private var amount: String
    @State private var included: Bool
    @State private var accountID: String

    init(commitment: FundingPlanCommitment, currency: String, eligibleAccounts: [Account], onChange: @escaping (String, String, Bool, String?) -> Void, onDelete: @escaping () -> Void) {
        self.commitment = commitment; self.currency = currency; self.eligibleAccounts = eligibleAccounts; self.onChange = onChange; self.onDelete = onDelete
        _label = State(initialValue: commitment.label)
        _amount = State(initialValue: (try? commitment.money.canonicalDecimalString()) ?? "")
        _included = State(initialValue: commitment.included)
        _accountID = State(initialValue: commitment.fundingAccountID ?? "")
    }

    var body: some View {
        HStack {
            Toggle("", isOn: $included).labelsHidden()
            TextField("Commitment", text: $label).textFieldStyle(.roundedBorder)
            Text(currency).foregroundStyle(LFTheme.textSecondary)
            TextField("0.00", text: $amount).textFieldStyle(.roundedBorder).frame(width: 110)
            Picker("Funding", selection: $accountID) {
                Text("Unassigned").tag("")
                ForEach(eligibleAccounts, id: \.id) { Text($0.nickname ?? $0.name).tag($0.repositoryAccountId ?? "") }
            }.frame(width: 180)
            Button("Apply") { onChange(label, amount, included, accountID.isEmpty ? nil : accountID) }.buttonStyle(.bordered)
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }.buttonStyle(.borderless)
        }
    }
}
