import SwiftUI

struct PayslipProposalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lfTheme) private var theme
    let statement: SalaryStatement
    let plan: FundingPlan
    let accounts: [Account]
    let onApply: (String) -> Bool
    @State private var accountID = ""
    @State private var reviewed = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Review salary draft").font(theme.typography.formTitle)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(MoneyFormatting.display(statement.evidence.printedNet)).font(theme.typography.sectionTitle)
            Text("Net pay from the \(AppDateDisplay.month(statement.evidence.financialPeriod.canonical)) payslip. Bank receipt is checked separately; this does not create a bank transaction.")
            if let cycle = plan.assistance?.salaryCycle ?? SalaryFundingCycle.expected(month: plan.month) {
                Text("Expected payday \(cycle.recurringStart.presentation) · bills generated \(cycle.billRange) · recurring payments \(cycle.recurringRange).")
            }
            LFAccountPicker(label: "Salary account", placeholder: "Choose account", selection: $accountID,
                options: accounts.filter { $0.nativeCurrency.code == "QAR" }.map {
                    .init(id: $0.repositoryAccountId ?? "", title: $0.preferredDisplayName, detail: $0.selectionContext)
                })
            Text("This replaces the draft’s fixed income (\(MoneyFormatting.display(plan.expectedFixedEarnings))), variable income (\(MoneyFormatting.display(plan.expectedVariableEarnings))) and payroll deductions with this net salary. Bills, balances and transfer choices remain. You can enter additional income afterwards.")
            Toggle("I have reviewed this change to my draft", isOn: $reviewed)
            if let error { Text(error).foregroundStyle(LFTheme.warning) }
            Button("Apply to draft") {
                if !onApply(accountID) { error = "The source or draft changed. Close this review and reopen the current proposal." }
            }.lfPrimaryAction().disabled(!reviewed || accountID.isEmpty)
            Text("Changes are kept automatically for this month. Other monthly entries stay available.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }.font(theme.typography.body).padding(24).frame(width: 650)
    }
}

// Editors protect a small, explicit owner decision. The surrounding full-width
// overview remains the normal place to compare accounts and dates.
enum PlanningEditorRequest: Identifiable {
    case recurring(RecurringDefinition?, RecurringCandidate?)
    case payment(RecurringPaymentProjection)
    case reserve(ReserveDesignation?)
    case contribution(ReserveDesignation)
    case budget, preferences, funding, historicalSalary
    case salary(SalaryAssistance)
    case prefills([RecurringPaymentProjection])
    var id: String {
        switch self {
        case .recurring(let value, let candidate): "recurring:" + (value?.id ?? candidate?.id ?? "new")
        case .payment(let value): value.id
        case .reserve(let value): "reserve:" + (value?.id ?? "new")
        case .contribution(let value): "contribution:" + value.id
        case .budget: "budget"
        case .preferences: "preferences"
        case .funding: "funding"
        case .historicalSalary: "historicalSalary"
        case .salary(let value): "salary:" + value.id
        case .prefills: "prefills"
        }
    }
}

struct PlanningEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lfTheme) private var theme
    let request: PlanningEditorRequest
    let metadata: FinancialIntelligenceSnapshot?
    let accounts: [IntelligenceAccountContext]
    var availableAccountIDs: Set<String>? = nil
    var excludedHistoryAccountIDs: Set<String> = []
    let rows: [SpendingSourceRow]
    let plan: FundingPlan
    let onMetadata: (PlanningMetadataEdit) throws -> Void
    let onAssistance: (PlanAssistance) -> Void
    let onSalary: (SalaryAssistance) -> Void
    let onPrefills: ([RecurringPaymentProjection]) -> Void
    @State private var title = ""
    @State private var accountID = ""
    @State private var amount = ""
    @State private var date = ""
    @State private var dueDay = ""
    @State private var endsOn = ""
    @State private var note = ""
    @State private var depositBalance = ""
    @State private var depositDate = ""
    @State private var availableDate = ""
    @State private var currency = "INR"
    @State private var kind: ReserveDesignation.Kind = .accountCash
    @State private var enabled = true
    @State private var waived = false
    @State private var predicates: [CategoryTextPredicate] = []
    @State private var selectedIDs: Set<String> = []
    @State private var search = ""
    @State private var preferences: IntelligencePreferences?
    @State private var budget: PlanAssistance?
    @State private var error: String?
    @State private var acknowledged = false
    @State private var adjustmentKind: PlanDatedAdjustment.Kind = .irregularCost
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pending: (() -> Void)?
#endif
    private var workspace: String { plan.workspaceID }
    private var sourceCurrency: String { accounts.first { $0.id == accountID }?.currency ?? currency }
    private var heading: String {
        switch request {
        case .recurring: "Recurring commitment"
        case .payment: "Review one payment"
        case .reserve: "Reserve target"
        case .contribution: "Plan a reserve contribution"
        case .budget: "Monthly plan assumptions"
        case .preferences: "Salary assistance"
        case .funding: "Account funding and actuals"
        case .historicalSalary: "Review historical salary credits"
        case .salary: "Review received salary"
        case .prefills: "Review monthly commitment prefills"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(heading).font(theme.typography.formTitle); Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch request {
                    case .recurring(let previous, let candidate): recurring(previous: previous, candidate: candidate)
                    case .payment(let value): payment(value)
                    case .reserve: reserve
                    case .contribution(let value): contribution(value)
                    case .budget: budgetInputs
                    case .preferences: salaryPreferences
                    case .funding: PlanningFundingEditor(plan: plan, metadata: metadata, accounts: accounts, availableAccountIDs: availableAccountIDs, excludedHistoryAccountIDs: excludedHistoryAccountIDs, rows: rows, onApply: onAssistance)
                    case .historicalSalary: historicalSalary
                    case .salary(let value): salaryProposal(value)
                    case .prefills(let values): prefills(values)
                    }
                }.padding(.vertical, 6)
            }
            if let error { Text(error).foregroundStyle(LFTheme.warning).textSelection(.enabled) }
        }.padding(24).frame(width: 820).frame(maxHeight: 760)
            .font(theme.typography.body).foregroundStyle(theme.palette.primaryText).background(theme.palette.contentSurface)
            .onAppear(perform: populate)
#if DEBUG
            .alert(DevelopmentProfileAcknowledgementPresentation.title,
                isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pending = nil } })) {
                    Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                        if let challenge { _ = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) }
                        let action = pending; pending = nil; challenge = nil; action?()
                    }
                    Button("Cancel", role: .cancel) { pending = nil; challenge = nil }
                } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }
    private var accountPicker: some View {
        LFAccountPicker(label: "Funding bank", placeholder: "Choose account", selection: $accountID,
            options: accounts.filter { availableAccountIDs?.contains($0.id) != false || $0.id == accountID }.map {
                .init(id: $0.id, title: $0.title, detail: $0.selectionContext + (availableAccountIDs?.contains($0.id) == false ? " · Saved account; unavailable for new funding" : ""))
            })
    }
    private func field(_ label: String, _ binding: Binding<String>) -> some View {
        LabeledContent(label) { TextField(label, text: binding).textFieldStyle(.roundedBorder).frame(maxWidth: 420) }
    }
    private func recurring(previous: RecurringDefinition?, candidate: RecurringCandidate?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let candidate {
                Text("Candidate from \(candidate.dates.count) source months. Confirm the amount, due day and start date; this pattern is not yet an obligation.").foregroundStyle(theme.palette.secondaryText)
                Text(candidate.narration).textSelection(.enabled)
            }
            field("Commitment name", $title)
            accountPicker
            HStack { Text("Native currency: \(sourceCurrency)"); Spacer(); Toggle("Enabled", isOn: $enabled) }
            field("Monthly amount", $amount)
            field("Due day (1–31)", $dueDay)
            field("Effective from (YYYY-MM-DD)", $date)
            field("Ends on (optional)", $endsOn)
            if let previous {
                DisclosureGroup("Saved effective-date history") {
                    ForEach(previous.revisions, id: \.effectiveFrom) { revision in
                        Text("From \(revision.effectiveFrom): \(revision.amount.decimal) \(revision.amount.currency), due day \(revision.dueDay)")
                    }
                }
                Text("Saving appends or corrects this effective-date rule. A one-month exception belongs in Review payment.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Text("Optional payment-match clues · all must match").font(theme.typography.body.weight(.semibold))
            ForEach(predicates.indices, id: \.self) { index in
                HStack {
                    Picker("Field", selection: $predicates[index].field) { Text("Narration").tag(CategoryTextPredicate.Field.narration); Text("Reference").tag(CategoryTextPredicate.Field.reference) }.labelsHidden().frame(width: 125)
                    Picker("Match", selection: $predicates[index].match) { Text("Contains").tag(CategoryTextPredicate.Match.contains); Text("Exactly").tag(CategoryTextPredicate.Match.exact) }.labelsHidden().frame(width: 100)
                    TextField("Original source text", text: $predicates[index].text).textFieldStyle(.roundedBorder)
                    Button("Remove") { predicates.remove(at: index) }.buttonStyle(.borderless)
                }
            }
            Button("Add source clue") { predicates.append(.init(field: .narration, match: .contains, text: "")) }.lfSecondaryAction()
            field("Note", $note)
            Button("Save recurring commitment") {
                execute {
                    guard let day = Int(dueDay), (1...31).contains(day), let _ = try? StatementDate(canonical: date), !title.trimmingCharacters(in: .whitespaces).isEmpty, !accountID.isEmpty else { throw PlanningEditorError.input("Enter a name, funding account, amount and valid effective/due dates.") }
                    let money = try nativeAmount(amount, currency: sourceCurrency)
                    var revisions = previous?.revisions ?? []
                    revisions.removeAll { $0.effectiveFrom == date }
                    revisions.append(.init(effectiveFrom: date, dueDay: day, amount: try PlanningAmount(money)))
                    let value = RecurringDefinition(id: previous?.id ?? UUID().uuidString, workspaceID: workspace, accountID: accountID,
                        title: title, revisions: revisions.sorted { $0.effectiveFrom < $1.effectiveFrom }, endsOn: endsOn.isEmpty ? nil : endsOn,
                        predicates: predicates, isEnabled: enabled, note: note)
                    if let candidate, previous == nil {
                        try onMetadata(.confirmRecurringCandidate(value, key: candidate.id, replacingPreferences: metadata?.preferences))
                    } else { try onMetadata(.recurring(value, replacing: previous)) }
                    dismiss()
                }
            }.lfPrimaryAction()
        }
    }
    private func payment(_ value: RecurringPaymentProjection) -> some View {
        let candidates = rows.filter { $0.accountID == value.definition.accountID && $0.currency == value.currency &&
            (selectedIDs.contains($0.id) || search.isEmpty ? value.suggestionIDs.contains($0.id) || selectedIDs.contains($0.id) : $0.text.localizedCaseInsensitiveContains(search)) }
        return VStack(alignment: .leading, spacing: 12) {
            Text(value.definition.title + " · " + value.date.presentation).font(theme.typography.sectionTitle)
            Text("Match actual debits and any reversing credits. Partial payments reduce this occurrence only; no source transaction is changed.").foregroundStyle(theme.palette.secondaryText)
            field("One-month amount override (optional)", $amount)
            Toggle("Waive the remaining amount for this occurrence", isOn: $waived)
            TextField("Search this account’s original narration or reference", text: $search).textFieldStyle(.roundedBorder)
            ForEach(candidates.prefix(80)) { row in
                Toggle(isOn: Binding(get: { selectedIDs.contains(row.id) }, set: { if $0 { selectedIDs.insert(row.id) } else { selectedIDs.remove(row.id) } })) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.transaction.description).textSelection(.enabled)
                        Text((row.date?.presentation ?? "Date unavailable") + " · " + MoneyFormatting.display(row.transaction.money) + " · " + (row.transaction.reference ?? ""))
                            .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    }
                }.toggleStyle(.checkbox)
            }
            if candidates.isEmpty { Text("No suggested match. Search the source text to inspect other payments or reversals.").foregroundStyle(theme.palette.secondaryText) }
            field("Payment note", $note)
            Button("Save payment review") {
                execute {
                    let previous = metadata?.occurrences.first { $0.id == value.id }
                    let result = RecurringOccurrence(id: value.id, workspaceID: workspace, definitionID: value.definition.id, dueDate: value.date.canonical,
                        amountOverride: amount.isEmpty ? nil : try PlanningAmount(nativeAmount(amount, currency: value.currency)),
                        isWaived: waived, transactionIDs: selectedIDs.sorted(), note: note)
                    try onMetadata(.occurrence(result, replacing: previous)); dismiss()
                }
            }.lfPrimaryAction()
        }
    }
    private var reserve: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("Reserve name", $title)
            Picker("Funding basis", selection: $kind) { Text("Bank cash after bills").tag(ReserveDesignation.Kind.accountCash); Text("Planning-only deposit").tag(ReserveDesignation.Kind.planningDeposit) }
            if kind == .accountCash { accountPicker }
            else { Picker("Currency", selection: $currency) { ForEach(["QAR", "INR", "USD"], id: \.self) { Text($0) } } }
            field("Target", $amount)
            if kind == .planningDeposit {
                Text("This is a labelled planning balance. It creates no investment asset, units, transaction or deposit statement.").foregroundStyle(theme.palette.secondaryText)
                field("Funded balance (leave blank if unknown)", $depositBalance)
                field("Balance date (YYYY-MM-DD)", $depositDate)
                field("Available from (optional)", $availableDate)
            }
            field("Note", $note)
            Button("Save reserve target") {
                execute {
                    let previous: ReserveDesignation? = if case .reserve(let value) = request { value } else { nil }
                    let selectedCurrency = kind == .accountCash ? sourceCurrency : currency
                    let value = ReserveDesignation(id: previous?.id ?? UUID().uuidString, workspaceID: workspace, accountID: kind == .accountCash ? accountID : nil,
                        title: title, kind: kind, target: try PlanningAmount(nativeAmount(amount, currency: selectedCurrency)),
                        planningBalance: kind == .planningDeposit && !depositBalance.isEmpty ? try PlanningAmount(nativeAmount(depositBalance, currency: selectedCurrency)) : nil,
                        planningBalanceDate: kind == .planningDeposit && !depositBalance.isEmpty ? depositDate : nil,
                        availableOn: kind == .planningDeposit && !availableDate.isEmpty ? availableDate : nil, note: note)
                    try onMetadata(.reserve(value, replacing: previous)); dismiss()
                }
            }.lfPrimaryAction()
            if case .reserve(let value?) = request {
                Button("Remove target", role: .destructive) { execute { try onMetadata(.removeReserve(value)); dismiss() } }.lfSecondaryAction()
                Text("A target referenced by a saved contribution cannot be removed. Edit that plan first.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
        }
    }
    private func contribution(_ value: ReserveDesignation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(value.title + " · " + value.target.currency).font(theme.typography.sectionTitle)
            Text("This is a monthly flow, separate from the protected-balance target. A same-account cash allocation changes designation without subtracting the cash twice.").foregroundStyle(theme.palette.secondaryText)
            accountPicker
            field("Contribution (blank removes this plan’s choice)", $amount)
            field("Planned date (YYYY-MM-DD)", $date)
            field("Reason if reducing the saved goal", $note)
            Button("Apply to editable plan") {
                execute {
                    var result = plan.assistance ?? .init(workspaceID: workspace, month: plan.month.canonical)
                    let previous = result.contributions.first { $0.designationID == value.id }
                    let money = amount.isEmpty ? nil : try nativeAmount(amount, currency: value.target.currency)
                    if let old = try previous?.amount.money(), (money?.amount ?? 0) < old.amount, note.trimmingCharacters(in: .whitespaces).isEmpty { throw PlanningEditorError.input("Explain the reduction so the saving goal is not silently lowered.") }
                    guard amount.isEmpty || (sourceCurrency == value.target.currency && !accountID.isEmpty && (try? StatementDate(canonical: date)) != nil) else { throw PlanningEditorError.input("Choose a bank in the reserve’s currency and a valid funding date.") }
                    result.contributions.removeAll { $0.designationID == value.id }
                    if let money { result.contributions.append(.init(designationID: value.id, fundingAccountID: accountID, amount: try PlanningAmount(money), dueDate: date)) }
                    result.reserveAllocationReviewed = true
                    if !note.isEmpty { result.allowanceOverrideReason = note }
                    onAssistance(result)
                }
            }.lfPrimaryAction()
            Text("Changes in the monthly plan are kept automatically.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }
    private var budgetInputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discretionary allowance").font(theme.typography.sectionTitle)
            accountPicker
            field("Monthly allowance (blank leaves it unset)", $amount)
            field("Reason for changing the allowance or goal", $note)
            Button("Apply allowance to draft") {
                execute {
                    var result = budget ?? .init(workspaceID: workspace, month: plan.month.canonical)
                    result.allowance = amount.isEmpty ? nil : try PlanningAmount(nativeAmount(amount, currency: sourceCurrency))
                    result.allowanceAccountID = amount.isEmpty ? nil : accountID
                    guard amount.isEmpty || !accountID.isEmpty else { throw PlanningEditorError.input("Choose the bank whose cash funds this allowance.") }
                    if let previous = try plan.assistance?.allowance?.money(), let next = try result.allowance?.money(), next.amount > previous.amount && note.trimmingCharacters(in: .whitespaces).isEmpty { throw PlanningEditorError.input("Explain the higher allowance and review its effect on saving.") }
                    result.allowanceOverrideReason = note
                    onAssistance(result)
                }
            }.lfSecondaryAction()
            Divider()
            Text("Dated income or one-off spending").font(theme.typography.sectionTitle)
            Text("Only future amounts not already in the dated bank balance belong here. Received salary and payroll ISP deductions must not be added or deducted again.").foregroundStyle(theme.palette.secondaryText)
            Picker("Kind", selection: $adjustmentKind) { Text("Expected net income").tag(PlanDatedAdjustment.Kind.expectedIncome); Text("Irregular cost").tag(PlanDatedAdjustment.Kind.irregularCost); Text("Discretionary spending provision").tag(PlanDatedAdjustment.Kind.discretionary) }
            field("Description", $title)
            field("Native amount", $depositBalance)
            field("Date (YYYY-MM-DD)", $date)
            Button("Add dated item to draft") {
                execute {
                    guard !accountID.isEmpty, !title.trimmingCharacters(in: .whitespaces).isEmpty, (try? StatementDate(canonical: date)) != nil else { throw PlanningEditorError.input("Choose an account, description and date.") }
                    var result = budget ?? .init(workspaceID: workspace, month: plan.month.canonical)
                    result.datedAdjustments.append(.init(id: UUID().uuidString, accountID: accountID, kind: adjustmentKind, title: title, amount: try PlanningAmount(nativeAmount(depositBalance, currency: sourceCurrency)), date: date))
                    onAssistance(result)
                }
            }.lfSecondaryAction()
            ForEach(budget?.datedAdjustments ?? []) { value in
                HStack {
                    Text("\(value.date) · \(value.title) · \(value.amount.decimal) \(value.amount.currency)")
                    Spacer()
                    Button("Remove") { var result = budget!; result.datedAdjustments.removeAll { $0.id == value.id }; onAssistance(result) }.buttonStyle(.borderless)
                }
            }
        }
    }
    private var salaryPreferences: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Prepare a reviewable salary-funded plan after salary arrives", isOn: Binding(get: { preferences?.salaryAssistanceEnabled ?? true }, set: { preferences?.salaryAssistanceEnabled = $0 }))
            Text("The plan is labelled by the salary-credit month. It covers bills issued since the previous payday and recurring payments before the next payday. Applying a proposal updates the monthly scratchpad automatically.").foregroundStyle(theme.palette.secondaryText)
            Text("Choose the enabled bank-credit rules that identify regular salary. Bonus, ad-hoc, transfer and payslip records do not create another salary receipt.").foregroundStyle(theme.palette.secondaryText)
            let sources = FinancialIntelligenceStore.shared.sources
            let rules = SpendingIntelligence.eligibleSalaryRules(categories: CategoryStore.shared.snapshot, sources: sources)
            if let issue = SpendingIntelligence.salarySetupIssue(preferences: preferences, categories: CategoryStore.shared.snapshot, sources: sources) {
                Text(issue).foregroundStyle(LFTheme.warning)
            }
            ForEach(rules) { rule in
                Toggle(rule.name, isOn: Binding(get: { preferences?.salaryRuleIDs.contains(rule.id) ?? false }, set: { if $0 { preferences?.salaryRuleIDs.insert(rule.id) } else { preferences?.salaryRuleIDs.remove(rule.id) } }))
            }
            if rules.isEmpty { Text("Create an enabled, account-specific salary rule in Transactions → Category rules first.") }
            LFAccountPicker(label: "CBQ cash account for Keep in CBQ", placeholder: "Choose bank account",
                selection: Binding(get: { preferences?.retentionAccountID ?? "" }, set: { preferences?.retentionAccountID = $0.isEmpty ? nil : $0 }),
                options: accounts.filter { $0.currency == "QAR" && (availableAccountIDs?.contains($0.id) != false || $0.id == preferences?.retentionAccountID) }.map {
                    .init(id: $0.id, title: $0.title, detail: $0.selectionContext)
                })
            Text("Monthly plan uses only its own Keep in CBQ amount. Plan insights compares that floor with the saved reserve target and protects the larger amount once. This account choice is independent of the salary switch.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Button("Save assistance preferences") { execute { if let value = preferences { try onMetadata(.preferences(value, replacing: metadata?.preferences)); dismiss(); SalaryAssistanceSession.shared.retry() } } }.lfPrimaryAction()
        }
    }
    private var historicalSalary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a bank salary credit to prepare its salary-funded plan. Bills generated since the previous payday and upcoming recurring payments are reviewed separately. This does not save or replace a plan.").foregroundStyle(theme.palette.secondaryText)
            if let metadata, let today = FinancialCalendar.statement(Date()) {
                let proposals = SalaryAssistanceSession.proposals(rows: rows, metadata: metadata, today: today, includeHistorical: true).filter { $0.targetMonth >= SalaryWorkspaceViewModel.firstPlanningMonth.canonical }
                Text("Monthly planning begins in \(AppDateDisplay.month(SalaryWorkspaceViewModel.firstPlanningMonth.canonical)). Earlier credits remain in Transactions and do not create an older plan.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                if proposals.isEmpty { Text("No unreviewed bank salary credits match the selected salary rules.") }
                ForEach(proposals.reversed()) { proposal in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Credit \(AppDateDisplay.civil(proposal.financialDate)) → \(AppDateDisplay.month(proposal.targetMonth)) salary plan")
                            if let row = rows.first(where: { $0.id == proposal.id }) { Text(row.transaction.description).font(theme.typography.secondary).textSelection(.enabled) }
                        }
                        Spacer()
                        Button("Prepare proposal") { execute { try onMetadata(.salary(proposal, replacing: nil)); dismiss() } }.lfSecondaryAction()
                    }
                    Divider()
                }
            }
        }
    }
    private func salaryProposal(_ value: SalaryAssistance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let row = rows.first(where: { $0.id == value.id }) {
                Text(MoneyFormatting.display(row.transaction.money)).font(theme.typography.sectionTitle)
                Text(row.accountTitle).font(theme.typography.body)
                Text(row.transaction.description).textSelection(.enabled)
            }
            Text("Received \(AppDateDisplay.civil(value.financialDate)) → \(AppDateDisplay.month(value.targetMonth)) plan")
            if let cycle = proposedCycle(for: value) {
                Text("Use this received date for the editable cycle: bills generated \(cycle.billRange); recurring payments \(cycle.recurringRange).")
            } else if value.planningBasis == nil {
                Text("This saved proposal retains its original following-month assignment.").foregroundStyle(theme.palette.secondaryText)
            }
            Text("Applying this proposal sets additional salary and payroll deductions to zero for this draft: the real net credit belongs in the bank balance. Existing commitments, reserves and manual FX choices remain. A balance predating the credit stays unavailable for the worksheet.").foregroundStyle(theme.palette.secondaryText)
            Text("Existing input: fixed \(MoneyFormatting.display(plan.expectedFixedEarnings)), variable \(MoneyFormatting.display(plan.expectedVariableEarnings)), deductions \(MoneyFormatting.display(plan.expectedDeductions)).")
            Toggle("I reviewed these changes; apply them to the editable month", isOn: $acknowledged)
            HStack {
                Button("Apply proposal") { onSalary(value) }.lfPrimaryAction().disabled(!acknowledged)
                Button("Dismiss proposal") { execute { var result = value; result.draftState = .dismissed; try onMetadata(.salary(result, replacing: value)); dismiss() } }.lfSecondaryAction()
            }
            Text("Other monthly entries are retained. The proposal is consumed when this valid plan is retained automatically.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }
    private func proposedCycle(for value: SalaryAssistance) -> SalaryFundingCycle? {
        guard value.planningBasis == .creditMonth,
              var cycle = plan.assistance?.salaryCycle ?? SalaryFundingCycle.expected(month: plan.month) else { return nil }
        cycle.payday = value.financialDate
        if let previous = cycle.previousSavedPayday(in: metadata) { cycle.previousPayday = previous }
        return cycle
    }
    private func prefills(_ values: [RecurringPaymentProjection]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("These amounts replace only the linked recurring rows in this month’s draft. Edited plan rows are shown alongside; the recurring template and imported facts stay unchanged.").foregroundStyle(theme.palette.secondaryText)
            ForEach(values) { value in
                HStack {
                    Text(value.definition.title + " · " + value.date.presentation)
                    Spacer()
                    let existingID = plan.assistance?.appliedRecurringIDs[value.id]
                    if let existing = (plan.qatarCommitments + plan.indiaCommitments).first(where: { $0.id == existingID }) { Text(MoneyFormatting.display(existing.money) + " →") }
                    Text("\(NSDecimalNumber(decimal: value.remaining).stringValue) \(value.currency)")
                }
            }
            Toggle("Apply these reviewed remaining amounts", isOn: $acknowledged)
            Button("Apply to editable plan") { onPrefills(values); dismiss() }.lfPrimaryAction().disabled(!acknowledged || values.isEmpty)
            Text("Monthly entries are kept automatically.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }
    private func populate() {
        date = FinancialCalendar.statement(Date())!.canonical
        preferences = metadata?.preferences ?? .init(workspaceID: workspace)
        budget = plan.assistance ?? .init(workspaceID: workspace, month: plan.month.canonical)
        switch request {
        case .recurring(let value, let candidate):
            if let value { title = value.title; accountID = value.accountID; endsOn = value.endsOn ?? ""; predicates = value.predicates; enabled = value.isEnabled; note = value.note
                if let revision = value.revisions.max(by: { $0.effectiveFrom < $1.effectiveFrom }) { amount = revision.amount.decimal; currency = revision.amount.currency; dueDay = String(revision.dueDay) }
            } else if let candidate { title = candidate.narration; accountID = candidate.accountID; amount = NSDecimalNumber(decimal: candidate.amount).stringValue; dueDay = String(candidate.dates.last!.day); predicates = [.init(field: .narration, match: .exact, text: candidate.narration)] }
        case .payment(let value):
            if let saved = metadata?.occurrences.first(where: { $0.id == value.id }) { amount = saved.amountOverride?.decimal ?? ""; selectedIDs = Set(saved.transactionIDs); waived = saved.isWaived; note = saved.note }
        case .reserve(let value):
            if let value { title = value.title; accountID = value.accountID ?? ""; kind = value.kind; currency = value.target.currency; amount = value.target.decimal; depositBalance = value.planningBalance?.decimal ?? ""; depositDate = value.planningBalanceDate ?? ""; availableDate = value.availableOn ?? ""; note = value.note }
        case .contribution(let value):
            currency = value.target.currency
            if let saved = plan.assistance?.contributions.first(where: { $0.designationID == value.id }) { amount = saved.amount.decimal; accountID = saved.fundingAccountID; date = saved.dueDate }
            else { date = "" }
        case .budget: accountID = plan.assistance?.allowanceAccountID ?? ""; amount = plan.assistance?.allowance?.decimal ?? ""; note = plan.assistance?.allowanceOverrideReason ?? ""
        default: break
        }
    }
    private func nativeAmount(_ text: String, currency: String) throws -> Money {
        let value = try PlannerInputCodec.money(text, currency: currency, locale: .current)
        guard value.amount >= 0 else { throw PlanningEditorError.input("Enter an amount of zero or greater.") }
        return value
    }
    private func execute(_ operation: @escaping () throws -> Void) {
        do { try operation(); error = nil }
        catch {
#if DEBUG
            if case DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) = error { challenge = value; pending = { execute(operation) }; return }
#endif
            self.error = error.localizedDescription
        }
    }
}

struct PlanningSalaryCycleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lfTheme) private var theme
    let plan: FundingPlan
    let metadata: FinancialIntelligenceSnapshot?
    let onApply: (SalaryFundingCycle) -> Bool
    @State private var day = 25
    @State private var error: String?
    private var proposed: SalaryFundingCycle? {
        guard var value = SalaryFundingCycle.expected(month: plan.month, day: day) else { return nil }
        if let previous = value.previousSavedPayday(in: metadata) { value.previousPayday = previous }
        if let current = plan.assistance?.salaryCycle, current.receivedSalaryID != nil {
            value.payday = current.payday; value.receivedSalaryID = current.receivedSalaryID
        }
        return value
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Salary funding dates").font(theme.typography.formTitle)
            Picker("Expected payday each month", selection: $day) {
                ForEach(1...31, id: \.self) { Text(String($0)).tag($0) }
            }.frame(maxWidth: 360)
            if let proposed {
                LabeledContent("Bills generated", value: proposed.billRange)
                LabeledContent("Recurring payments due", value: proposed.recurringRange)
                Text("Bills generated after the previous payday are funded by this salary. Upcoming recurring payments, including the start of next month, are funded until the next payday.")
                    .foregroundStyle(theme.palette.secondaryText)
                Text("Payment due dates still apply. Manually included bills keep their amounts and dates; review anything due before payday. Shorter months use their last day.")
                    .foregroundStyle(theme.palette.secondaryText)
                if proposed.receivedSalaryID != nil {
                    Text("The imported salary’s received date stays \(proposed.recurringStart.presentation). The expected day sets the neighbouring scheduled paydays.")
                }
            }
            if let error { Text(error).foregroundStyle(LFTheme.warning) }
            HStack {
                Text("Applies to this month; changes are kept automatically.").foregroundStyle(theme.palette.secondaryText)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply dates") {
                    if let proposed, onApply(proposed) { dismiss() }
                    else { error = "A linked payment falls outside these dates. Review that draft row before changing the cycle." }
                }.lfPrimaryAction().keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 740)
            .font(theme.typography.body).foregroundStyle(theme.palette.primaryText).background(theme.palette.contentSurface)
            .onAppear { day = plan.assistance?.salaryCycle?.expectedDay ?? 25 }
    }
}

struct PlanningAccountsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lfTheme) private var theme
    let accounts: [Account]
    let workspaceID: String
    let generation: ProviderGenerationToken
    @State private var previous: IntelligencePreferences?
    @State private var excluded: Set<String> = []
    @State private var error: String?
#if DEBUG
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
#endif

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Planning accounts").font(theme.typography.formTitle)
            Text("Choose the accounts available in Budget Planning across all months. Removed accounts keep their imported history. Existing bills remain for review and reassignment.")
                .foregroundStyle(theme.palette.secondaryText)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(accounts) { account in
                        if let id = account.repositoryAccountId {
                            Toggle(isOn: Binding(get: { !excluded.contains(id) }, set: { included in
                                if included { excluded.remove(id) } else { excluded.insert(id) }
                            })) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.preferredDisplayName).font(theme.typography.body.weight(.semibold))
                                    Text([account.sourceAccountNumberLabel, account.nativeCurrency.code].compactMap { $0 }.joined(separator: " · "))
                                        .foregroundStyle(theme.palette.secondaryText)
                                }
                            }.toggleStyle(.checkbox).padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
            }
            if let error { Text(error).foregroundStyle(LFTheme.warning).textSelection(.enabled) }
            HStack {
                Text("Select an account again to add it back.").foregroundStyle(theme.palette.secondaryText)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save availability", action: save).lfPrimaryAction().keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 660).frame(maxHeight: 680)
            .font(theme.typography.body).foregroundStyle(theme.palette.primaryText).background(theme.palette.contentSurface)
            .onAppear {
                previous = FinancialIntelligenceStore.shared.snapshot?.preferences
                excluded = previous?.excludedPlanningAccountIDs ?? []
            }
#if DEBUG
            .alert(DevelopmentProfileAcknowledgementPresentation.title,
                isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil } })) {
                    Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                        if let challenge { _ = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) }
                        challenge = nil; save()
                    }
                    Button("Cancel", role: .cancel) { challenge = nil }
                } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }

    private func save() {
        var value = previous ?? IntelligencePreferences(workspaceID: workspaceID)
        value.excludedPlanningAccountIDs = excluded
        do {
            try FinancialIntelligenceCoordinator().applyPlanning(.preferences(value, replacing: previous), generation: generation)
            dismiss()
        } catch {
#if DEBUG
            if case DevelopmentProfileAcknowledgementError.acknowledgementRequired(let value) = error { challenge = value; return }
#endif
            self.error = error.localizedDescription
        }
    }
}

private enum PlanningEditorError: LocalizedError {
    case input(String)
    var errorDescription: String? { if case .input(let text) = self { text } else { nil } }
}
