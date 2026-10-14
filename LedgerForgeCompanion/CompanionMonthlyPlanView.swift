import SwiftUI
import UIKit

/// Labels supplied from the Mac-selected account scope; no discovery in the view.
struct CompanionPlanAccountLabel: Identifiable {
    let id: String
    let title: String
    let context: String
    let currency: String
}

/// Caller maps these to the exact current edit revision, not the latest file write.
struct CompanionPlanStatus {
    enum Retention { case keeping, kept, failed(String) }
    enum Delivery { case fromMacSnapshot, waitingToSend, waitingForMac, acknowledged, offline, conflict, held(String) }
    let retention: Retention
    let delivery: Delivery
    let permitsEditing: Bool
    /// Caller also checks lineage, unresolved merge and dependency compatibility.
    let permitsCalculation: Bool
}

/// Content only; CompanionPhoneShell owns the NavigationStack.
/// onEdit must apply through PortableMonthlyPlanEditor and immediately retain the
/// complete mutation + lexical context atomically before advertising local success.
/// New IDs are allocated once per user action and retained with that action.
@MainActor
struct CompanionMonthlyPlanView: View {
    let editor: PortableMonthlyPlanEditor
    let accountLabels: [CompanionPlanAccountLabel]
    let relatedCards: [CompanionPlanAccountLabel]
    let availableMonths: [SelectedStatementMonth]
    let latestAlDarQuote: AlDarReferenceQuote?
    let status: CompanionPlanStatus
    let onEdit: (PortableMonthlyPlanEditor.Edit) -> Void
    let onSelectMonth: (SelectedStatementMonth) -> Void
    let onReviewConflict: (() -> Void)?
    var sourceContext: String? = nil
    var makeRowID: () -> String = { UUID().uuidString }
    var timeZone: TimeZone = .current
    @FocusState private var focusedField: String?
    @State private var dateTarget: DateTarget?
    @State private var selectedDate = Date()

    private enum DateTarget: Identifiable {
        case fx
        case bill(PortableMonthlyPlanEditor.Region, String)
        var id: String {
            switch self { case .fx: "fx"; case .bill(let region, let id): region.rawValue + ":" + id }
        }
    }
    private var plan: FundingPlan { editor.presentationPlan }
    private var editable: Bool { editor.canEdit && status.permitsEditing }
    private var calculation: FundingPlanCalculation? {
        guard status.permitsCalculation, !editor.salaryReceiptNeedsRevalidation else { return nil }
        if case .kept = status.retention {
            if case .conflict = status.delivery { return nil }
            return editor.visibleCalculation
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                Picker("Plan month", selection: Binding(get: { plan.month.canonical }, set: { key in
                    focusedField = nil
                    if let month = availableMonths.first(where: { $0.canonical == key }) { onSelectMonth(month) }
                })) {
                    // Retain the current month even if the available-month inventory is incomplete.
                    Text(plan.month.canonical).tag(plan.month.canonical)
                    ForEach(availableMonths.filter { $0 != plan.month }, id: \.canonical) { month in
                        Text(month.canonical).tag(month.canonical)
                    }
                }
                if let cycle = plan.assistance?.salaryCycle {
                    Text("Recurring payments: \(cycle.recurringStart.presentation)–\(cycle.recurringEnd.presentation)")
                        .font(.caption).foregroundStyle(.secondary)
                } else { Text("Calendar-month plan").font(.caption).foregroundStyle(.secondary) }
                retentionStatus
                deliveryStatus
                if let sourceContext, !sourceContext.isEmpty {
                    Text("Last received Mac basis: " + sourceContext)
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let message = editor.errorMessage { Label(message, systemImage: "exclamationmark.circle") }
            }
            Section("Monthly summary") {
                if let calculation {
                    result("Available to transfer", calculation.transferablePrincipal)
                    result("Estimated INR", calculation.estimatedINR)
                    result("Minimum reqd transfer", calculation.indiaFundingShortfall)
                    result("Required QAR principal", calculation.requiredQARPrincipal)
                    result("Balance available", calculation.finalQARBuffer)
                    if let value = calculation.qatarObligationShortfall, value.amount > 0 {
                        Text("Qatar bills need \(MoneyFormatting.display(value)) more cash before any transfer.")
                    }
                    if let value = calculation.qatarReserveGap, value.amount > 0 {
                        Text("Funds after Qatar bills are \(MoneyFormatting.display(value)) below Keep in CBQ.")
                    }
                } else {
                    Text(editor.salaryReceiptNeedsRevalidation
                         ? "The salary receipt basis needs review on the Mac before current totals can be shown."
                         : "Current totals are unavailable while entries are incomplete, being retained or awaiting review.")
                        .foregroundStyle(.secondary)
                }
            }
            balanceSection("Starting cash · QAR", currency: "QAR")
            Section("Salary adjustments · QAR") {
                if let receipt = editor.receipt { Text(receipt.explanation).font(.caption).foregroundStyle(.secondary) }
                scalar("Fixed earnings", field: .fixed)
                scalar("Variable earnings", field: .variable)
                if plan.calculationVersion == .legacy { scalar("Deductions", field: .deductions) }
                if let calculation { result("Income included this month", calculation.expectedNet) }
                Text("Received salary in starting cash is not added again. Payroll deductions are already included in take-home salary.")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(!editable)
            if plan.calculationVersion == .budgetV1 { deductionsSection }
            billsSection("Qatar bills", region: .qatar)
            Section("Keep and transfer · QAR") {
                if plan.calculationVersion == .budgetV1 { scalar("Keep in CBQ", field: .reserve) }
                scalar("Transfer fee", field: .fee)
                if plan.calculationVersion == .legacy { scalar("Planned investment", field: .investment) }
            }.disabled(!editable)
            billsSection("Bills in India", region: .india)
            balanceSection("Existing INR funds", currency: "INR")
            rateSection
            if !editor.scratchpad.excludedRecurringOccurrenceIDs.isEmpty {
                Section("Recurring payments") {
                    Text("\(editor.scratchpad.excludedRecurringOccurrenceIDs.count) removed recurring occurrences remain excluded from this month.")
                    Text("Removing a generated bill retains its monthly exclusion. Global recurring rules stay on the Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Monthly Plan")
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .accessibilityHint("Dismisses the keyboard. Entries are kept automatically.")
            }
        }
        .sheet(item: $dateTarget) { target in dateSheet(target) }
    }

    @ViewBuilder private var retentionStatus: some View {
        switch status.retention {
        case .keeping: ProgressView("Keeping changes on this iPhone…")
        case .kept: Label("Kept on this iPhone", systemImage: "checkmark.circle")
        case .failed(let message): Label(message, systemImage: "exclamationmark.triangle")
        }
    }
    @ViewBuilder private var deliveryStatus: some View {
        switch status.delivery {
        case .fromMacSnapshot: Text("From Mac snapshot · no local changes").font(.caption)
        case .waitingToSend: Text("Waiting to send to Mac").font(.caption)
        case .waitingForMac: Text("Published to folder · waiting for Mac acknowledgement").font(.caption)
        case .acknowledged: Text("Received by Mac").font(.caption)
        case .offline: Text("Offline · pending changes have not reached the Mac").font(.caption)
        case .held(let message):
            Text(message).font(.caption)
            if let onReviewConflict { Button("Review connection", action: onReviewConflict) }
        case .conflict:
            Text("Two edits need your choice. Both are retained.")
            if let onReviewConflict { Button("Review both edits", action: onReviewConflict) }
        }
    }

    private func scalar(_ label: String, field: PortableMonthlyPlanEditor.MoneyField) -> some View {
        input(label + " · QAR", key: field.rawValue,
              value: inputText(field.rawValue, fallback: editor.moneyText(field)),
              keyboard: [.fee, .reserve].contains(field) ? .decimalPad : .numbersAndPunctuation) {
            onEdit(.money(field, text: $0))
        }
    }
    private var deductionsSection: some View {
        Section("Additional deductions · QAR") {
            ForEach(plan.deductions) { deduction in
                DisclosureGroup {
                    Group {
                    input("Deduction name", key: "deduction.label." + deduction.id,
                          value: inputText("deduction.label." + deduction.id, fallback: deduction.label)) {
                        onEdit(.deduction(id: deduction.id, label: $0, amount: nil, recurs: nil))
                    }
                    input("Amount · QAR", key: "deduction.amount." + deduction.id,
                          value: inputText("deduction.amount." + deduction.id, fallback: exact(deduction.money)), keyboard: .decimalPad) {
                        onEdit(.deduction(id: deduction.id, label: nil, amount: $0, recurs: nil))
                    }
                    Toggle("Carry to the next month", isOn: Binding(get: { deduction.recurs }, set: {
                        onEdit(.deduction(id: deduction.id, label: nil, amount: nil, recurs: $0))
                    }))
                    Button("Remove deduction", role: .destructive) { onEdit(.removeDeduction(id: deduction.id)) }
                    }.disabled(!editable)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inputText("deduction.label." + deduction.id, fallback: deduction.label).isEmpty ? "Unnamed deduction" : inputText("deduction.label." + deduction.id, fallback: deduction.label))
                        Text(inputText("deduction.amount." + deduction.id, fallback: exact(deduction.money)) + " QAR").monospacedDigit()
                        if editor.scratchpad.fieldErrors["deduction.label." + deduction.id] != nil || editor.scratchpad.fieldErrors["deduction.amount." + deduction.id] != nil {
                            Label("Needs completion", systemImage: "exclamationmark.circle").font(.caption)
                        }
                    }
                }
            }
            Button("Add deduction", systemImage: "plus") { onEdit(.addDeduction(id: makeRowID())) }
                .disabled(!editable)
        }
    }

    private func balanceSection(_ title: String, currency: String) -> some View {
        Section(title) {
            ForEach(editor.accounts.filter { $0.nativeCurrency.code == currency && !editor.manuallyExcludedPlanningAccountIDs.contains($0.id) }, id: \.id) { account in
                let balance = plan.balances.first { $0.accountID == account.id }
                let label = accountLabels.first { $0.id == account.id }
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(label?.title ?? "Saved account unavailable", isOn: Binding(
                        get: { balance?.included == true && !editor.excludedHistoryAccountIDs.contains(account.id) },
                        set: { onEdit(.accountIncluded(accountID: account.id, included: $0, newBalanceID: balance?.id ?? makeRowID())) }))
                    if let label { Text(label.context).font(.caption).foregroundStyle(.secondary) }
                    if account.isHistoryOnly { Text("History-only account · this month’s selection").font(.caption) }
                    input("Planning balance · " + currency, key: "balance." + account.id,
                          value: inputText("balance." + account.id, fallback: balance?.money.map(exact) ?? ""), keyboard: .numbersAndPunctuation) {
                        onEdit(.manualBalance(accountID: account.id, text: $0, newBalanceID: balance?.id ?? makeRowID()))
                    }.disabled(editor.excludedHistoryAccountIDs.contains(account.id))
                    if let balance {
                        Text("Balance as of " + (balance.financialBalanceDate?.canonical ?? "date unavailable"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(provenance(balance.provenance)).font(.caption).foregroundStyle(.secondary)
                    }
                    if editor.scratchpad.unavailableBalanceAccountIDs.contains(account.id) {
                        Text("Source balance unavailable. Your retained estimate is unchanged.").font(.caption)
                    }
                }
            }
            ForEach(plan.balances.filter { $0.nativeCurrency.code == currency &&
                (!editor.accounts.map(\.id).contains($0.accountID) || editor.manuallyExcludedPlanningAccountIDs.contains($0.accountID)) }) { balance in
                VStack(alignment: .leading, spacing: 4) {
                    Text(accountName(balance.accountID))
                    Text(editor.manuallyExcludedPlanningAccountIDs.contains(balance.accountID)
                         ? "Excluded from planning on the Mac · retained entry" : "Saved account unavailable · retained entry")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(inputText("balance." + balance.accountID,
                        fallback: balance.money.map(exact) ?? "Amount unavailable") + " " + currency).monospacedDigit()
                    if let error = editor.scratchpad.fieldErrors["balance." + balance.accountID] {
                        Label(error, systemImage: "exclamationmark.circle").font(.caption)
                    }
                    Text("Balance as of " + (balance.financialBalanceDate?.canonical ?? "date unavailable"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(provenance(balance.provenance)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.disabled(!editable)
    }

    private func billsSection(_ title: String, region: PortableMonthlyPlanEditor.Region) -> some View {
        let rows = region == .qatar ? plan.qatarCommitments : plan.indiaCommitments
        return Section(title) {
            ForEach(rows.filter { $0.isInAccountScope(excluding: editor.excludedHistoryAccountIDs, fundingOverrides: plan.assistance?.billFundingAccounts) }) { bill in
                DisclosureGroup {
                    billFields(bill, region: region).disabled(!editable)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(inputText("label." + bill.id, fallback: bill.label))
                        Text(inputText("amount." + bill.id, fallback: exact(bill.money)) + " " + bill.money.currency.code).monospacedDigit()
                        if editor.scratchpad.fieldErrors["label." + bill.id] != nil || editor.scratchpad.fieldErrors["amount." + bill.id] != nil {
                            Label("Needs completion", systemImage: "exclamationmark.circle").font(.caption)
                        }
                        Text((bill.included ? "Included" : "Not included") + " · " + (plan.dueDate(for: bill)?.canonical ?? "Date not set"))
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            Button("Add bill", systemImage: "plus") { onEdit(.addCommitment(region: region, id: makeRowID())) }
                .disabled(!editable)
        }
    }

    @ViewBuilder private func billFields(_ bill: FundingPlanCommitment, region: PortableMonthlyPlanEditor.Region) -> some View {
        Toggle("Include this bill", isOn: Binding(get: { bill.included }, set: {
            onEdit(.commitment(region: region, id: bill.id, field: .included, text: String($0)))
        }))
        input("Bill name", key: "label." + bill.id, value: inputText("label." + bill.id, fallback: bill.label)) {
            onEdit(.commitment(region: region, id: bill.id, field: .label, text: $0))
        }
        input("Amount · " + bill.money.currency.code, key: "amount." + bill.id,
              value: inputText("amount." + bill.id, fallback: exact(bill.money)),
              keyboard: plan.calculationVersion == .legacy ? .numbersAndPunctuation : .decimalPad) {
            onEdit(.commitment(region: region, id: bill.id, field: .amount, text: $0))
        }
        if plan.calculationVersion == .budgetV1 {
            Button("Due date: " + (plan.dueDate(for: bill)?.canonical ?? "Choose date")) {
                focusedField = nil; selectedDate = date(plan.dueDate(for: bill)) ?? date(plan.recurringStart) ?? Date()
                dateTarget = .bill(region, bill.id)
            }
            if !editor.isConfirmedRecurringRow(bill.id), plan.dueDate(for: bill) != nil {
                Button("Clear due date") { onEdit(.commitmentDate(region: region, id: bill.id, date: nil, timeZone: timeZone)) }
            }
        }
        Toggle("This month only", isOn: Binding(get: { !bill.recurs }, set: {
            onEdit(.commitmentDetails(region: region, id: bill.id, recurs: !$0, temporary: nil, remark: nil))
        }))
        if bill.recurs {
            Toggle("Reduced for this month only", isOn: Binding(get: { bill.temporaryCarryBasis != nil }, set: {
                onEdit(.commitmentDetails(region: region, id: bill.id, recurs: nil, temporary: $0, remark: nil))
            }))
            Text(bill.temporaryCarryBasis.map { "Next month retains " + MoneyFormatting.display($0) } ?? "Next month keeps the full amount when a temporary reduction is used.")
                .font(.caption).foregroundStyle(.secondary)
        }
        input("Day / remark (optional)", key: "remark." + bill.id, value: bill.remark) {
            onEdit(.commitmentDetails(region: region, id: bill.id, recurs: nil, temporary: nil, remark: $0))
        }
        if editor.isConfirmedRecurringRow(bill.id) {
            Text("Funding account: " + accountName(bill.fundingAccountID))
        } else {
            Picker("Related card", selection: Binding(get: { bill.fundingAccountID ?? "" }, set: {
                onEdit(.commitment(region: region, id: bill.id, field: .account, text: $0))
            })) {
                Text("None").tag("")
                ForEach(relatedCards.filter { $0.currency == bill.money.currency.code }) { card in Text(card.title).tag(card.id) }
                if let id = bill.fundingAccountID, !relatedCards.contains(where: { $0.id == id && $0.currency == bill.money.currency.code }) {
                    Text(accountName(id)).tag(id)
                }
            }
        }
        if let fundingID = plan.assistance?.billFundingAccounts?[bill.id] {
            Text("Funding bank: " + accountName(fundingID)).font(.caption)
        }
        Text(provenance(bill.provenance)).font(.caption).foregroundStyle(.secondary)
        Button("Remove bill", role: .destructive) { onEdit(.removeCommitment(region: region, id: bill.id)) }
    }

    private var rateSection: some View {
        Section("Rate details") {
            if plan.referenceMode == .alDar {
                Text("Plan’s Al Dar reference")
                Text(plan.effectiveAlDarReference.map { "1 QAR = \($0.displayRate) INR" } ?? "Rate unavailable")
                if let quote = plan.effectiveAlDarReference { Text("Fetched " + quote.fetchedAtISO).font(.caption) }
            }
            input("INR for 1 QAR · monthly manual rate", key: "fx.rate",
                  value: editor.scratchpad.rawText["fx.rate"] ?? "", keyboard: .decimalPad) {
                onEdit(.manualFX(rate: $0, date: editor.scratchpad.rawText["fx.date"] ?? ""))
            }
            Button("Observation date: " + (editor.scratchpad.rawText["fx.date"].flatMap { $0.isEmpty ? nil : $0 } ?? "Choose date")) {
                focusedField = nil
                selectedDate = date(try? StatementDate(canonical: editor.scratchpad.rawText["fx.date"] ?? "")) ?? Date()
                dateTarget = .fx
            }
            if let error = editor.scratchpad.fieldErrors["fx.date"] { Text(error).font(.caption) }
            Button("Use Al Dar instead") { onEdit(.useAlDar(latestAlDarQuote)) }
                .disabled(latestAlDarQuote == nil || plan.calculationVersion != .budgetV1)
            Text("Uses the last reference received from the Mac. The iPhone does not fetch rates.")
                .font(.caption).foregroundStyle(.secondary)
        }.disabled(!editable)
    }

    private func input(_ title: String, key: String, value: String, keyboard: UIKeyboardType = .default,
                       change: @escaping @MainActor @Sendable (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline)
            if editable {
                TextField(title, text: Binding(get: { value }, set: change))
                    .keyboardType(keyboard).focused($focusedField, equals: key)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityLabel(title).accessibilityIdentifier("monthlyPlan." + key)
                    .frame(minHeight: 44)
            } else {
                // Disabled single-line fields cannot be scrolled to inspect long
                // retained remarks or raw input during conflict/recovery review.
                Text(value.isEmpty ? "Empty entry" : value)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityLabel(title).accessibilityValue(value.isEmpty ? "Empty entry" : value)
                    .accessibilityIdentifier("monthlyPlan." + key)
            }
            if let error = editor.scratchpad.fieldErrors[key] {
                Label(error, systemImage: "exclamationmark.circle").font(.caption)
            }
        }
    }
    private func inputText(_ key: String, fallback: String) -> String {
        let raw = editor.scratchpad.rawText[key] ?? fallback
        return editor.scratchpad.untouchedZeroFields.contains(key) && raw == "0" ? "" : raw
    }
    private func result(_ title: String, _ value: Money?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value.map { MoneyFormatting.display($0) } ?? "Unavailable").font(.headline).monospacedDigit()
        }.accessibilityElement(children: .combine)
    }
    private func exact(_ money: Money) -> String { (try? money.canonicalDecimalString()) ?? "" }
    private func accountName(_ id: String?) -> String {
        guard let id else { return "None" }
        return (accountLabels + relatedCards).first { $0.id == id }?.title ?? "Saved account unavailable"
    }
    private func provenance(_ value: FundingPlanValueProvenance) -> String {
        switch value {
        case .manual: "Your estimate"
        case .carried: "Copied from an earlier plan"
        case .capturedAccountBalance(let timestamp): "Captured account balance · " + timestamp
        }
    }
    private func date(_ day: StatementDate?) -> Date? {
        guard let day else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))
    }
    private func dateRange(_ target: DateTarget) -> ClosedRange<Date>? {
        guard case .bill(_, let id) = target, editor.isConfirmedRecurringRow(id),
              let lower = date(plan.recurringStart), let upper = date(plan.recurringEnd) else { return nil }
        return lower...upper
    }
    private func dateSheet(_ target: DateTarget) -> some View {
        NavigationStack {
            Form {
                if let range = dateRange(target) {
                    DatePicker("Date", selection: $selectedDate, in: range, displayedComponents: .date)
                } else { DatePicker("Date", selection: $selectedDate, displayedComponents: .date) }
            }
            .environment(\.timeZone, timeZone)
            .navigationTitle("Choose date").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dateTarget = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        switch target {
                        case .bill(let region, let id): onEdit(.commitmentDate(region: region, id: id, date: selectedDate, timeZone: timeZone))
                        case .fx:
                            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
                            let fields = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                            if let year = fields.year, let month = fields.month, let day = fields.day,
                               let selected = try? StatementDate(year: year, month: month, day: day) {
                                onEdit(.manualFX(rate: editor.scratchpad.rawText["fx.rate"] ?? "", date: selected.canonical, rateWasEdited: false))
                            }
                        }
                        dateTarget = nil
                    }.disabled(!editable)
                }
            }
        }
    }
}
