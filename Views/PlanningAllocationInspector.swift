import SwiftUI

struct PlanningAllocationInspector: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var planner: SalaryWorkspaceViewModel
    let row: AllocationEditorRow
    let availableWidth: CGFloat
    let onRemove: () -> Void
    @State private var editingAmount: AllocationEditorField?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 220), spacing: 20, alignment: .top),
              count: availableWidth >= 1120 ? 3 : availableWidth >= 700 ? 2 : 1)
    }
    private var transfer: PlanTransfer? {
        guard case .transfer(let id) = row.id else { return nil }
        return planner.plan.assistance?.transfers?.first { $0.id == id }
    }
    private var contribution: PlanContribution? {
        guard case .contribution(let id) = row.id else { return nil }
        return planner.plan.assistance?.contributions.first { $0.id == id }
    }
    private var reserve: ReserveDesignation? {
        guard let contribution else { return nil }
        return planner.allocationReserves.first { $0.id == contribution.designationID }
    }
    private var investment: PlanInvestmentIntention? {
        guard case .investment(let id) = row.id else { return nil }
        return planner.plan.assistance?.surplusAllocation?.investments.first { $0.id == id }
    }
    private var sourceID: String { row.sourceAccountID ?? "" }
    private var selectedFundingTransfer: String? {
        contribution?.fundingTransferID ?? transfer?.fundingTransferID ?? investment?.fundingTransferID
    }
    private var isIBKR: Bool {
        if case .ibkr = investment?.instrument { return true }
        return false
    }

    var body: some View {
        LFPanel(variant: .inspector, contentSpacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.destination).font(theme.typography.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.kind + " · " + planner.allocationStatus(for: row.id).title)
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                if row.id != .retention {
                    Button("Remove allocation", role: .destructive, action: onRemove)
                        .lfSecondaryAction().disabled(!planner.canEdit)
                }
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                if row.id == .retention {
                    amountField("Retain in CBQ", field: .amount, currency: "QAR")
                    detail("Account", planner.allocationAccountTitle(sourceID))
                    detail("Purpose", row.purpose)
                } else {
                    sourcePicker
                    if let transfer { destinationPicker(transfer) }
                    else { detail("Destination", row.destination) }
                    dateField
                    if let transfer {
                        amountField("Expected receipt", field: .received, currency: transfer.received.currency)
                        detail("Calculated principal", PlanningAllocationFormat.amount(transfer.sent))
                        detail("Purpose", row.purpose)
                    } else {
                        amountField("Planned allocation", field: .amount, currency: row.amount?.currency ?? "")
                        fundingTransferPicker
                        detail("Purpose", row.purpose)
                    }
                    if investment != nil {
                        textField(isIBKR ? "Exact IBKR conid" : "Exact mutual fund scheme code", field: .instrumentID)
                        textField("Selected instrument name", field: .instrumentTitle)
                        if isIBKR { textField("Instrument quote currency", field: .quoteCurrency, placeholder: "ISO currency code") }
                    }
                }
            }
            .disabled(!planner.canEdit)
            if let qualification = planner.allocationAccountQualification(sourceID) {
                warning(qualification)
            }
            if let transfer {
                transferDetails(transfer)
            } else if let contribution, let reserve {
                contributionDetails(contribution, reserve: reserve)
            } else if investment != nil {
                Text("This instruction reserves the funding amount for the exact instrument entered. It does not establish units, an order or a purchase.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            } else {
                Text("Keep in CBQ is a choice within this month’s surplus. It does not change mandatory bills or establish funded emergency reserves.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text(planner.allocationStatus(for: row.id).title).font(theme.typography.body.weight(.semibold))
                Text(planner.allocationEvidenceStatus(for: row.id))
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            if planner.allocationStatus(for: row.id) == .incompleteEntry {
                Text("Complete the highlighted fields before this entry can be approved in the plan.")
                    .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            }
        }
        .font(theme.typography.body)
        .accessibilityIdentifier("planner.allocation.inspector")
        .onChange(of: row.id) { _, _ in editingAmount = nil }
    }

    private var sourcePicker: some View {
        let accounts = planner.eligibleAllocationSources(for: row.id)
        return VStack(alignment: .leading, spacing: 7) {
            Text("Funding account").font(theme.typography.secondary)
            Picker("Funding account", selection: Binding(get: { sourceID }, set: { planner.setAllocationFundingAccount($0, row: row.id) })) {
                Text("Choose account").tag("")
                if !sourceID.isEmpty && !accounts.contains(where: { $0.id == sourceID }) {
                    Text(planner.allocationAccountTitle(sourceID) + " · needs review").tag(sourceID)
                }
                ForEach(accounts) { account in Text(accountTitle(account)).tag(account.id) }
            }.labelsHidden().tint(theme.palette.primaryText).frame(maxWidth: .infinity).controlSize(.large)
                .accessibilityIdentifier("planner." + row.id.fieldKey(.fundingAccount))
            fieldError(.fundingAccount)
        }
    }

    private func destinationPicker(_ transfer: PlanTransfer) -> some View {
        let destinations = planner.eligibleAllocationDestinations(from: sourceID)
        return VStack(alignment: .leading, spacing: 7) {
            Text("Destination account").font(theme.typography.secondary)
            Picker("Destination account", selection: Binding(get: { transfer.toAccountID }, set: { planner.setAllocationDestinationAccount($0, row: row.id) })) {
                Text("Choose eligible destination").tag("")
                if !transfer.toAccountID.isEmpty && !destinations.contains(where: { $0.id == transfer.toAccountID }) {
                    Text(planner.allocationAccountTitle(transfer.toAccountID) + " · needs review").tag(transfer.toAccountID)
                }
                ForEach(destinations) { account in Text(accountTitle(account)).tag(account.id) }
            }.labelsHidden().tint(theme.palette.primaryText).frame(maxWidth: .infinity).controlSize(.large)
                .accessibilityIdentifier("planner." + row.id.fieldKey(.destinationAccount))
            fieldError(.destinationAccount)
        }
    }

    private var fundingTransferPicker: some View {
        let transfers = planner.eligibleAllocationFundingTransfers(for: row.id)
        return VStack(alignment: .leading, spacing: 7) {
            Text("Funding comes from").font(theme.typography.secondary)
            Picker("Funding comes from", selection: Binding(get: { selectedFundingTransfer ?? "" }, set: { planner.setAllocationFundingTransfer($0.isEmpty ? nil : $0, row: row.id) })) {
                Text("Existing cash in selected account").tag("")
                if let selectedFundingTransfer, !transfers.contains(where: { $0.id == selectedFundingTransfer }) {
                    Text("Saved transfer · needs review").tag(selectedFundingTransfer)
                }
                ForEach(transfers) { transfer in
                    Text(PlanningAllocationFormat.date(transfer.date) + " · "
                         + planner.allocationAccountTitle(transfer.fromAccountID) + " · "
                         + PlanningAllocationFormat.amount(transfer.received)).tag(transfer.id)
                }
            }.labelsHidden().tint(theme.palette.primaryText).frame(maxWidth: .infinity).controlSize(.large)
                .accessibilityIdentifier("planner." + row.id.fieldKey(.fundingTransfer))
            fieldError(.fundingTransfer)
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Intended date").font(theme.typography.secondary)
            if let date = try? StatementDate(canonical: planner.allocationText(.date, row: row.id)),
               let instant = FinancialCalendar.instant(date) {
                DatePicker("Intended date", selection: Binding(get: { instant }, set: { value in
                    if let day = FinancialCalendar.statement(value) {
                        planner.setAllocationText(.date, row: row.id, text: day.canonical)
                    }
                }), displayedComponents: .date)
                .labelsHidden().environment(\.calendar, FinancialCalendar.calendar)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .controlSize(.large).frame(minHeight: 36, alignment: .leading)
                .accessibilityIdentifier("planner." + row.id.fieldKey(.date))
            } else {
                entry("YYYY-MM-DD", field: .date)
            }
            fieldError(.date)
        }
    }

    private func transferDetails(_ transfer: PlanTransfer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if transfer.sent.currency != transfer.received.currency {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    detail("Planning FX", fxDescription)
                    detail("Conversion basis", transfer.conversionBasis.isEmpty ? "Complete account and receipt details" : transfer.conversionBasis)
                    detail("International fee assumption", PlanningAllocationFormat.money(planner.plan.configuredTransferFee))
                }
                Toggle("This remittance includes the required India bill funding", isOn: Binding(
                    get: { planner.plan.assistance?.surplusAllocation?.requiredIndiaTransferID == transfer.id },
                    set: { planner.setAllocationIncludesRequiredIndia($0, transferID: transfer.id) }))
                    .toggleStyle(.checkbox).disabled(!planner.canEdit)
                Text(planner.plan.assistance?.surplusAllocation?.requiredIndiaTransferID == transfer.id
                     ? "Required India principal and the ordinary fee are already charged in Monthly Plan. Only the additional amount consumes surplus here."
                     : "An additional remittance consumes surplus and the applicable fee. The ordinary required remittance remains in Monthly Plan.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    fundingTransferPicker
                    amountField("Required India funding carried onward (optional)", field: .requiredIndiaFunding, currency: "INR")
                    detail("Fee treatment", "Domestic own-account transfer · no fee")
                }.disabled(!planner.canEdit)
                Text("An onward transfer can carry required India bill funding. That portion remains committed to bills and cannot fund another allocation.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            if let qualification = planner.allocationAccountQualification(transfer.toAccountID) { warning(qualification) }
            if let issue = planner.allocationError(.amount, row: row.id) { warning(issue) }
            Text("Expected receipts are planning estimates. Recorded bank debits, receipts and fees determine what actually happened.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private func contributionDetails(_ contribution: PlanContribution, reserve: ReserveDesignation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if reserve.kind == .accountCash,
               reserve.accountID == planner.allocationMetadata?.preferences?.retentionAccountID,
               contribution.fundingAccountID == reserve.accountID, contribution.fundingTransferID == nil {
                Toggle("This designation includes the existing Keep in CBQ amount", isOn: Binding(
                    get: { planner.plan.assistance?.surplusAllocation?.keepInCBQDesignationID == reserve.id },
                    set: { planner.setAllocationIncludesRetention($0, designationID: reserve.id) }))
                    .toggleStyle(.checkbox).disabled(!planner.canEdit)
                Text("Select only when these are the same retained funds. Their overlap is then counted once.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            Text(reserve.kind == .planningDeposit
                 ? "This is a planned reserve deposit. A contribution does not create a deposit asset or establish accessible reserve funding."
                 : "This is a designation within the funding account. It does not create a bank transfer; available reserve funding still depends on balances and bills.")
                .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }

    private var fxDescription: String {
        if planner.plan.referenceMode == .manual {
            return planner.plan.planningFX.map { "1 QAR = ₹" + NSDecimalNumber(decimal: $0.inrPerQAR).stringValue } ?? "Not established"
        }
        return planner.plan.effectiveAlDarReference.map { "1 QAR = ₹" + $0.displayRate } ?? "Not established"
    }

    private func accountTitle(_ account: IntelligenceAccountContext) -> String {
        account.selectionTitle + (account.routeType == "NRO" ? " · Protected emergency cash" : "")
    }

    private func amountField(_ title: String, field: AllocationEditorField, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title + (currency.isEmpty ? "" : " · " + currency)).font(theme.typography.secondary)
            entry("Amount", field: field, amount: true)
            LFNumericInputFeedback(isEditing: editingAmount == field, error: planner.allocationError(field, row: row.id),
                hint: editingAmount == field ? PlannerInputCodec.amountInWords(planner.allocationText(field, row: row.id), currency: currency, locale: planner.allocationInputLocale) : nil)
        }
    }

    private func textField(_ title: String, field: AllocationEditorField, placeholder: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(theme.typography.secondary)
            entry(placeholder ?? title, field: field)
            fieldError(field)
        }
    }

    private func entry(_ placeholder: String, field: AllocationEditorField, amount: Bool = false) -> some View {
        TextField(placeholder, text: Binding(
            get: { planner.allocationText(field, row: row.id) },
            set: { if $0 != planner.allocationText(field, row: row.id) { planner.setAllocationText(field, row: row.id, text: $0) } }),
            onEditingChanged: { editing in if amount { editingAmount = editing ? field : nil } })
            .font(theme.typography.body).monospacedDigit()
            .multilineTextAlignment(amount ? .trailing : .leading)
            .frame(minHeight: 30).lfTextField()
            .accessibilityLabel(placeholder)
            .accessibilityIdentifier("planner." + row.id.fieldKey(field))
    }

    @ViewBuilder private func fieldError(_ field: AllocationEditorField) -> some View {
        if let error = planner.allocationError(field, row: row.id) { warning(error) }
    }
    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Text(value).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }.frame(minHeight: 44, alignment: .topLeading)
    }
    private func warning(_ text: String) -> some View {
        Text(text).font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
            .fixedSize(horizontal: false, vertical: true)
    }
}
