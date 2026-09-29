import SwiftUI

/// Month-local owner assumptions. A planned transfer never creates a ledger
/// transaction; matching replaces forecast legs with the existing source facts.
struct PlanningFundingEditor: View {
    @Environment(\.lfTheme) private var theme
    let plan: FundingPlan
    let metadata: FinancialIntelligenceSnapshot?
    let accounts: [IntelligenceAccountContext]
    let rows: [SpendingSourceRow]
    let onApply: (PlanAssistance) -> Void
    @State private var draft: PlanAssistance?
    @State private var fromID = ""
    @State private var toID = ""
    @State private var receivedText = ""
    @State private var transferDate = ""
    @State private var cardID = ""
    @State private var fundingID = ""
    @State private var cardAmount = ""
    @State private var cardDate = ""
    @State private var confirmedCard = false
    @State private var replacedBillID = ""
    @State private var matchingID: String?
    @State private var matchesTransfer = false
    @State private var selected: Set<String> = []
    @State private var search = ""
    @State private var message: String?

    private var cards: [IntelligenceAccountContext] { FinancialIntelligenceStore.shared.sources.accounts.filter { $0.domain == "credit_card" } }
    private var latestCard: CardStatement? {
        CardStore.shared.snapshot.statements.filter { $0.liabilityAccountID == cardID }.max {
            (($0.statementDate ?? $0.period?.end)?.canonical ?? "") < (($1.statementDate ?? $1.period?.end)?.canonical ?? "")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let matchingID { actualPicker(matchingID) }
            else {
                billFunding
                Divider()
                cardFunding
                Divider()
                transfers
                Divider()
                actualLinks
                Toggle("I have reviewed this month’s reserve allocation, including any zero contributions", isOn: Binding(get: { draft?.reserveAllocationReviewed ?? false }, set: { draft?.reserveAllocationReviewed = $0 }))
                Button("Apply funding assumptions to draft") { if let draft { onApply(draft) } }.lfPrimaryAction()
                Text("Use Save in the monthly plan to keep these choices. Nothing here sends money or changes an imported transaction.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            }
            if let message { Text(message).foregroundStyle(LFTheme.warning) }
        }.onAppear { draft = plan.assistance ?? .init(workspaceID: plan.workspaceID, month: plan.month.canonical) }
    }
    private var billFunding: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Funding banks for this month’s bills").font(theme.typography.sectionTitle)
            Text("The monthly worksheet’s related card identifies a liability. Choose the bank which supplies the cash here.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            ForEach((plan.qatarCommitments + plan.indiaCommitments).filter(\.included)) { bill in
                Picker(bill.label, selection: Binding(get: { draft?.billFundingAccounts?[bill.id] ?? (accounts.contains { $0.id == bill.fundingAccountID } ? bill.fundingAccountID ?? "" : "") }, set: { value in
                    if draft?.billFundingAccounts == nil { draft?.billFundingAccounts = [:] }
                    draft?.billFundingAccounts?[bill.id] = value.isEmpty ? nil : value
                })) {
                    Text("Choose funding bank").tag("")
                    ForEach(accounts.filter { $0.currency == bill.money.currency.code }) { Text($0.selectionTitle).tag($0.id) }
                }
            }
        }
    }
    private var cardFunding: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review remaining card payment").font(theme.typography.sectionTitle)
            Picker("Card account", selection: $cardID) {
                Text("Choose card").tag("")
                ForEach(cards) { Text($0.selectionTitle).tag($0.id) }
            }.onChange(of: cardID) { _, _ in
                confirmedCard = false
                cardAmount = latestCard?.newBalance.flatMap { try? $0.canonicalDecimalString() } ?? ""
                cardDate = latestCard?.dueDate?.canonical ?? ""
                replacedBillID = ""
            }
            if let latestCard {
                Text("Statement \((latestCard.statementDate ?? latestCard.period?.end)?.presentation ?? "date unavailable") · reported balance \(latestCard.newBalance.map { MoneyFormatting.display($0) } ?? "unavailable")")
                    .font(theme.typography.secondary).textSelection(.enabled)
            }
            Picker("Pay from", selection: $fundingID) {
                Text("Choose bank").tag("")
                ForEach(accounts.filter { $0.currency == cards.first(where: { $0.id == cardID })?.currency }) { Text($0.selectionTitle).tag($0.id) }
            }
            TextField("Remaining bank payment · native amount", text: $cardAmount).textFieldStyle(.roundedBorder)
            TextField("Payment date · YYYY-MM-DD", text: $cardDate).textFieldStyle(.roundedBorder)
            Picker("Replace an existing related bill", selection: $replacedBillID) {
                Text("Separate cash need").tag("")
                ForEach((plan.qatarCommitments + plan.indiaCommitments).filter { $0.fundingAccountID == cardID }) { Text($0.label).tag($0.id) }
            }
            Text("If the worksheet already includes this card payment, select that bill so the forecast counts it once.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
            Toggle("I reviewed payments already made and this is only the remaining cash need", isOn: $confirmedCard)
            Button("Use reviewed remaining payment") {
                act {
                    guard confirmedCard, let card = latestCard, let account = accounts.first(where: { $0.id == fundingID }),
                          account.currency == cards.first(where: { $0.id == cardID })?.currency,
                          (try? StatementDate(canonical: cardDate)) != nil else { throw PlanningFundingError.input("Choose the card, funding bank, due date and confirm the remaining amount.") }
                    let money = try money(cardAmount, currency: account.currency)
                    draft?.datedAdjustments.removeAll { $0.cardAccountID == cardID }
                    draft?.datedAdjustments.append(.init(id: UUID().uuidString, accountID: fundingID, kind: .irregularCost,
                        title: "Remaining " + (cards.first { $0.id == cardID }?.title ?? "card") + " payment", amount: try PlanningAmount(money), date: cardDate,
                        cardAccountID: cardID, cardStatementID: card.id, replacesCommitmentID: replacedBillID.isEmpty ? nil : replacedBillID))
                }
            }.lfSecondaryAction().disabled(!confirmedCard)
            Text("This is a labelled planning assumption for the selected statement. New statement evidence renews the review. It creates a bank cash need, not a second purchase expense.").font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
        }
    }
    private var transfers: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Planned own-account funding").font(theme.typography.sectionTitle)
            Picker("From bank", selection: $fromID) {
                Text("Choose bank").tag("")
                ForEach(accounts) { Text($0.selectionTitle).tag($0.id) }
            }
            Picker("To bank", selection: $toID) {
                Text("Choose bank").tag("")
                ForEach(accounts.filter { destination in accounts.first(where: { $0.id == fromID }).map { PlanningIntelligence.permitsPlanningRoute(from: $0, to: destination, retentionAccountID: metadata?.preferences?.retentionAccountID) } ?? false }) {
                    Text($0.selectionTitle).tag($0.id)
                }
            }
            TextField("Amount needed in receiving bank’s currency", text: $receivedText).textFieldStyle(.roundedBorder)
            TextField("Funding date · YYYY-MM-DD", text: $transferDate).textFieldStyle(.roundedBorder)
            if let preview = try? transferPreview() {
                Text("Planned principal: " + MoneyFormatting.display(preview.sent) + " → " + MoneyFormatting.display(preview.received))
                if preview.sent.currency != preview.received.currency { Text("Plus the one configured fee: " + MoneyFormatting.display(plan.configuredTransferFee)).font(theme.typography.secondary) }
            }
            Button("Add planned funding") {
                act {
                    let preview = try transferPreview()
                    guard (try? StatementDate(canonical: transferDate)) != nil else { throw PlanningFundingError.input("Enter a valid funding date.") }
                    if preview.sent.currency != preview.received.currency, draft?.transfers?.contains(where: { $0.sent.currency != $0.received.currency }) == true { throw PlanningFundingError.input("Edit or remove the existing QAR remittance first. This monthly plan applies one remittance fee.") }
                    if draft?.transfers == nil { draft?.transfers = [] }
                    draft?.transfers?.append(.init(id: UUID().uuidString, fromAccountID: fromID, toAccountID: toID,
                        sent: try PlanningAmount(preview.sent), received: try PlanningAmount(preview.received), date: transferDate,
                        conversionBasis: plan.referenceMode == .manual ? "Month-local manual rate" : "Month-local Al Dar reference"))
                }
            }.lfSecondaryAction()
            ForEach(draft?.transfers ?? []) { value in
                HStack {
                    Text("\(value.date) · \(value.sent.decimal) \(value.sent.currency) → \(value.received.decimal) \(value.received.currency)")
                    Spacer()
                    Button("Match actuals") { matchingID = value.id; matchesTransfer = true; selected = Set(value.transactionIDs ?? []); search = "" }.lfSecondaryAction()
                    Button("Remove") { draft?.transfers?.removeAll { $0.id == value.id } }.buttonStyle(.borderless)
                }
            }
        }
    }
    private var actualLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Replace dated forecasts with recorded actuals").font(theme.typography.sectionTitle)
            ForEach(draft?.datedAdjustments ?? []) { value in
                HStack {
                    Text("\(value.date) · \(value.title) · \(value.amount.decimal) \(value.amount.currency)")
                    Spacer()
                    Button("Match actuals") { matchingID = value.id; matchesTransfer = false; selected = Set(value.transactionIDs ?? []); search = "" }.lfSecondaryAction()
                    Button("Remove") { draft?.datedAdjustments.removeAll { $0.id == value.id } }.buttonStyle(.borderless)
                }
            }
        }
    }
    private func actualPicker(_ id: String) -> some View {
        let transfer = draft?.transfers?.first { $0.id == id }
        let adjustment = draft?.datedAdjustments.first { $0.id == id }
        let candidates = rows.filter { row in
            let eligible: Bool
            if matchesTransfer { eligible = row.accountID == transfer?.fromAccountID && row.isBankOut || row.accountID == transfer?.toAccountID && row.isBankIn }
            else { eligible = row.accountID == adjustment?.accountID && (adjustment?.kind == .expectedIncome ? row.isBankIn : row.isBankOut) }
            return eligible && (selected.contains(row.id) || !search.isEmpty && row.text.localizedCaseInsensitiveContains(search))
        }.sorted { ($0.date?.canonical ?? "", $0.id) > ($1.date?.canonical ?? "", $1.id) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Choose recorded actuals after reviewing original text, dates and both account effects. Partial matches reduce only their own forecast leg.").font(theme.typography.secondary)
            TextField("Search original narration or reference", text: $search).textFieldStyle(.roundedBorder)
            ForEach(candidates.prefix(100)) { row in
                Toggle(isOn: Binding(get: { selected.contains(row.id) }, set: { if $0 { selected.insert(row.id) } else { selected.remove(row.id) } })) {
                    VStack(alignment: .leading) {
                        Text(row.transaction.description)
                        Text(row.accountTitle + " · " + (row.date?.presentation ?? "Date unavailable") + " · " + MoneyFormatting.display(row.transaction.money)).font(theme.typography.secondary)
                    }
                }
            }
            Button("Use selected actuals") {
                if matchesTransfer, let index = draft?.transfers?.firstIndex(where: { $0.id == id }) { draft?.transfers?[index].transactionIDs = selected.sorted() }
                else if let index = draft?.datedAdjustments.firstIndex(where: { $0.id == id }) { draft?.datedAdjustments[index].transactionIDs = selected.sorted() }
                matchingID = nil
            }.lfPrimaryAction()
            Button("Back without changing matches") { matchingID = nil }.lfSecondaryAction()
        }
    }
    private func transferPreview() throws -> (sent: Money, received: Money) {
        guard let from = accounts.first(where: { $0.id == fromID }), let to = accounts.first(where: { $0.id == toID }),
              PlanningIntelligence.permitsPlanningRoute(from: from, to: to, retentionAccountID: metadata?.preferences?.retentionAccountID) else { throw PlanningFundingError.input("Choose two banks on a permitted route.") }
        let received = try money(receivedText, currency: to.currency)
        guard let sent = PlanningIntelligence.transferPrincipal(received: received, fromCurrency: from.currency, plan: plan) else { throw PlanningFundingError.input("The monthly plan needs a valid conversion reference.") }
        return (sent, received)
    }
    private func money(_ text: String, currency: String) throws -> Money {
        let value = try PlannerInputCodec.money(text, currency: currency, locale: .current)
        guard value.amount >= 0 else { throw PlanningFundingError.input("Enter a nonnegative amount.") }
        return value
    }
    private func act(_ operation: () throws -> Void) { do { try operation(); message = nil } catch { message = error.localizedDescription } }
}

private enum PlanningFundingError: LocalizedError {
    case input(String)
    var errorDescription: String? { if case .input(let message) = self { message } else { nil } }
}
