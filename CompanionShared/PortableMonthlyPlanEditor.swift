import Foundation

/// Operational lexical metadata accompanies the raw scratchpad, not ledger Money.
/// The default is the known origin locale; it must not be guessed from the receiver.
nonisolated struct PlannerLexicalContext: Codable, Equatable, Sendable {
    var defaultLocaleIdentifier: String?
    var localeIdentifiersByField: [String: String]
}

/// Exact Mac-selected bank identity/scope. No account or source discovery occurs here.
nonisolated struct PlannerAccountInput: Equatable, Sendable {
    let id: String
    let nativeCurrency: CurrencyCode
    let isHistoryOnly: Bool
    var repositoryAccountId: String? { id }
}

nonisolated struct PlannerSalaryReceiptBasis: Codable, Equatable, Sendable {
    let workspaceID: String
    let month: SelectedStatementMonth
    let link: PayslipFunding?
    let cycle: SalaryFundingCycle?
    let balance: FundingPlanBalance?
    let linkedAccountExcluded: Bool
    init(plan: FundingPlan, excludedAccounts: Set<String>) {
        workspaceID = plan.workspaceID; month = plan.month
        link = plan.assistance?.payslipFunding; cycle = plan.assistance?.salaryCycle
        balance = plan.balances.first { $0.accountID == plan.assistance?.payslipFunding?.accountID }
        linkedAccountExcluded = plan.assistance?.payslipFunding.map { excludedAccounts.contains($0.accountID) } ?? false
    }
}

/// A value-only draft editor. Persistence, delivery, source discovery and application
/// availability belong to its platform owner. Call apply, then retain atomically.
@MainActor
struct PortableMonthlyPlanEditor {
    enum MoneyField: String, CaseIterable { case fixed, variable, deductions, fee, investment, reserve }
    enum Region: String { case qatar, india }
    enum CommitmentField: String { case label, amount, included, account }
    enum Edit {
        case money(MoneyField, text: String)
        case manualFX(rate: String, date: String, rateWasEdited: Bool = true)
        case useAlDar(AlDarReferenceQuote?)
        case addDeduction(id: String)
        case deduction(id: String, label: String?, amount: String?, recurs: Bool?)
        case removeDeduction(id: String)
        case addCommitment(region: Region, id: String)
        case commitment(region: Region, id: String, field: CommitmentField, text: String)
        case commitmentDetails(region: Region, id: String, recurs: Bool?, temporary: Bool?, remark: String?)
        case commitmentDate(region: Region, id: String, date: Date?, timeZone: TimeZone)
        case removeCommitment(region: Region, id: String)
        case accountIncluded(accountID: String, included: Bool, newBalanceID: String)
        case manualBalance(accountID: String, text: String, newBalanceID: String)
    }
    struct Mutation {
        /// Hints for semantic grouping. Cross-linked row effects must be one durable edit.
        let itemID: String
        let relatedOccurrenceIDs: Set<String>
        let changed: Bool
        let salaryReceiptNeedsRevalidation: Bool
    }
    private(set) var scratchpad: MonthlyPlanScratchpad
    private(set) var lexicalContext: PlannerLexicalContext
    private(set) var errorMessage: String?
    private(set) var selectedHistoryAccountIDs: Set<String>
    let accounts: [PlannerAccountInput]
    let allHistoryAccountIDs: Set<String>
    let manuallyExcludedPlanningAccountIDs: Set<String>
    let receiptBasis: PlannerSalaryReceiptBasis?
    let receipt: PayslipReceiptState?
    var canEdit: Bool
    private var availableAlDarQuote: AlDarReferenceQuote?
    private let presentation: CompanionPlannerPresentation?
    private var locale: Locale
    private var newBalanceRowID = ""

    init(scratchpad: MonthlyPlanScratchpad, lexicalContext: PlannerLexicalContext,
         accounts: [PlannerAccountInput], allHistoryAccountIDs: Set<String>,
         selectedHistoryAccountIDs: Set<String>, manuallyExcludedPlanningAccountIDs: Set<String>,
         receipt: PayslipReceiptState?, receiptBasis: PlannerSalaryReceiptBasis?, canEdit: Bool,
         presentation: CompanionPlannerPresentation? = nil) {
        self.scratchpad = scratchpad; self.lexicalContext = lexicalContext
        self.accounts = accounts; self.allHistoryAccountIDs = allHistoryAccountIDs
        self.selectedHistoryAccountIDs = selectedHistoryAccountIDs
        self.manuallyExcludedPlanningAccountIDs = manuallyExcludedPlanningAccountIDs
        self.receipt = receipt; self.receiptBasis = receiptBasis; self.canEdit = canEdit
        self.presentation = presentation
        availableAlDarQuote = scratchpad.plan.effectiveAlDarReference
        locale = Locale(identifier: lexicalContext.defaultLocaleIdentifier ?? "en_US_POSIX")
    }
    private static var zeroQAR: Money { try! Money(canonicalDecimal: "0.00", currency: "QAR") }
    private(set) var plan: FundingPlan { get { scratchpad.plan } set { scratchpad.plan = newValue } }
    private var rawText: [String: String] { get { scratchpad.rawText } set { scratchpad.rawText = newValue } }
    private var fieldErrors: [String: String] { get { scratchpad.fieldErrors } set { scratchpad.fieldErrors = newValue } }
    private var untouchedZeroFields: Set<String> { get { scratchpad.untouchedZeroFields } set { scratchpad.untouchedZeroFields = newValue } }
    private var unavailableCurrentBalanceAccountIDs: Set<String> { get { scratchpad.unavailableBalanceAccountIDs } set { scratchpad.unavailableBalanceAccountIDs = newValue } }
    private var preReductionBasis: [String: Money] { get { scratchpad.preReductionBasis } set { scratchpad.preReductionBasis = newValue } }
    private var excludedRecurringOccurrenceIDs: Set<String> { get { scratchpad.excludedRecurringOccurrenceIDs } set { scratchpad.excludedRecurringOccurrenceIDs = newValue } }
    var excludedHistoryAccountIDs: Set<String> { allHistoryAccountIDs.subtracting(selectedHistoryAccountIDs) }
    var excludedPlanningAccountIDs: Set<String> { manuallyExcludedPlanningAccountIDs.union(excludedHistoryAccountIDs) }
    private var eligibleAccounts: [PlannerAccountInput] { accounts.filter { !excludedPlanningAccountIDs.contains($0.id) && ["QAR", "INR"].contains($0.nativeCurrency.code) } }
    private var visibleMoneyFields: [MoneyField] { plan.calculationVersion == .budgetV1 ? [.fixed, .variable, .reserve, .fee] : [.fixed, .variable, .deductions, .fee, .investment] }
    var hasValidCalculation: Bool {
        PlannerInputValidity.hasValidCalculation(plan: plan, fieldErrors: fieldErrors, excludedHistoryAccountIDs: excludedHistoryAccountIDs)
    }
    var salaryReceiptNeedsRevalidation: Bool {
        plan.assistance?.payslipFunding != nil && receiptBasis != PlannerSalaryReceiptBasis(plan: plan, excludedAccounts: excludedPlanningAccountIDs)
    }
    /// Mirror the Mac's valid open worksheet recalculation on a copy only. An
    /// incomplete entry retains its saved source quote; manual and legacy modes
    /// keep their exact selected basis. No presentation value enters scratchpad.
    var presentationPlan: FundingPlan {
        guard canEdit, hasValidCalculation, plan.calculationVersion == .budgetV1,
              plan.referenceMode == .alDar, let presentation else { return plan }
        var value = plan
        value.effectiveAlDarReference = presentation.alDarQuote
        return value
    }

    /// The platform owner additionally masks pending/failed retention and unresolved sync conflict.
    var visibleCalculation: FundingPlanCalculation? {
        guard hasValidCalculation else { return nil }
        return FundingPlanCalculator.calculate(presentationPlan, excludingAccounts: excludedPlanningAccountIDs,
            historyOnlyAccountIDs: excludedHistoryAccountIDs,
            salaryReceipt: salaryReceiptNeedsRevalidation ? .needsReview : receipt)
    }
    private func parseLocale(for key: String) -> Locale? {
        (lexicalContext.localeIdentifiersByField[key] ?? lexicalContext.defaultLocaleIdentifier).map { Locale(identifier: $0) }
    }
    /// Unknown origin is retained explicitly; it does not invalidate a saved parsed value.
    var uncertainInputKeys: Set<String> {
        Set(rawText.keys.filter { key in
            let numeric = MoneyField.allCases.contains { $0.rawValue == key } || key == "fx.rate"
                || key.hasPrefix("deduction.amount.") || key.hasPrefix("amount.") || key.hasPrefix("balance.")
            return numeric && parseLocale(for: key) == nil
        })
    }
    private mutating func editedLocale(_ key: String, _ identifier: String) {
        lexicalContext.localeIdentifiersByField[key] = identifier
    }
    private func hasRow(_ id: String) -> Bool {
        plan.deductions.contains { $0.id == id } || plan.qatarCommitments.contains { $0.id == id }
            || plan.indiaCommitments.contains { $0.id == id } || plan.balances.contains { $0.id == id }
    }
    /// The locale is explicit for this user edit; unchanged fields retain their own origin.
    /// The ID is allocated once by the owner and retained with the pending edit.
    @discardableResult
    mutating func apply(_ edit: Edit, inputLocaleIdentifier: String) -> Mutation? {
        guard canEdit else { return nil }
        let before = scratchpad, beforeLexical = lexicalContext
        let beforeSelection = selectedHistoryAccountIDs
        let beforeError = errorMessage, beforeLocale = locale
        var replayedNumericInput = false
        locale = Locale(identifier: inputLocaleIdentifier)
        errorMessage = nil
        var item = "", related = Set<String>()
        switch edit {
        case let .money(field, text):
            guard plan.calculationVersion == .legacy || ![MoneyField.deductions, .investment].contains(field) else { return nil }
            item = "scalar:" + field.rawValue
            guard text != displayedInputText(field.rawValue, fallback: moneyText(field)) else { replayedNumericInput = true; break }
            editedLocale(field.rawValue, inputLocaleIdentifier)
            _ = updateMoney(field, text: text)
        case let .manualFX(rate, date, rateWasEdited):
            guard rateWasEdited || rate == (rawText["fx.rate"] ?? "") else { return nil }
            item = "fx"
            let rateChanged = rate != (rawText["fx.rate"] ?? "")
            guard rateChanged || date != (rawText["fx.date"] ?? "") else { replayedNumericInput = true; break }
            if rateWasEdited && rateChanged { editedLocale("fx.rate", inputLocaleIdentifier) }
            setFX(rateText: rate, dateText: date)
        case let .useAlDar(quote):
            guard plan.calculationVersion == .budgetV1 else { return nil }
            item = "fx"; availableAlDarQuote = quote; useSharedAlDar()
            lexicalContext.localeIdentifiersByField["fx.rate"] = nil
        case let .addDeduction(id):
            guard !id.isEmpty, !hasRow(id), plan.calculationVersion == .budgetV1 else { return nil }
            item = "deduction:" + id; editedLocale("deduction.amount." + id, inputLocaleIdentifier); addDeduction(id: id)
        case let .deduction(id, label, amount, recurs):
            guard plan.deductions.contains(where: { $0.id == id }) else { return nil }
            item = "deduction:" + id
            let row = plan.deductions.first { $0.id == id }!
            let changedAmount: String? = amount.flatMap { text in
                text == displayedInputText("deduction.amount." + id, fallback: exactText(row.money)) ? nil : text
            }
            if changedAmount != nil { editedLocale("deduction.amount." + id, inputLocaleIdentifier) }
            guard label != nil || changedAmount != nil || recurs != nil else { replayedNumericInput = true; break }
            editDeduction(id: id, label: label, amount: changedAmount, recurs: recurs)
        case let .removeDeduction(id):
            guard plan.deductions.contains(where: { $0.id == id }) else { return nil }
            item = "deduction:" + id; removeDeduction(id: id)
            lexicalContext.localeIdentifiersByField["deduction.amount." + id] = nil
        case let .addCommitment(region, id):
            guard !id.isEmpty, !hasRow(id) else { return nil }
            item = "commitment:" + id; editedLocale("amount." + id, inputLocaleIdentifier)
            addCommitment(region: region.rawValue, id: id)
        case let .commitment(region, id, field, text):
            guard rows(in: region).contains(where: { $0.id == id }) else { return nil }
            guard field != .account || !isConfirmedRecurringRow(id) else { return nil }
            item = "commitment:" + id
            if field == .amount {
                let row = rows(in: region).first { $0.id == id }!
                guard text != displayedInputText("amount." + id, fallback: exactText(row.money)) else { replayedNumericInput = true; break }
                editedLocale("amount." + id, inputLocaleIdentifier)
            }
            editCommitment(region: region.rawValue, id: id, field: field.rawValue, text: text)
        case let .commitmentDetails(region, id, recurs, temporary, remark):
            guard rows(in: region).contains(where: { $0.id == id }) else { return nil }
            item = "commitment:" + id
            let rewritesAmount = temporary == false && rows(in: region).first(where: { $0.id == id })?.temporaryCarryBasis != nil && recurs != false
            setCommitmentDetails(region: region.rawValue, id: id, recurs: recurs, temporary: temporary, remark: remark)
            if rewritesAmount { editedLocale("amount." + id, inputLocaleIdentifier) }
        case let .commitmentDate(region, id, date, zone):
            guard rows(in: region).contains(where: { $0.id == id }), plan.calculationVersion == .budgetV1 else { return nil }
            item = "commitment:" + id
            setBillDate(region: region.rawValue, id: id, date: date, timeZone: zone)
        case let .removeCommitment(region, id):
            guard rows(in: region).contains(where: { $0.id == id }) else { return nil }
            item = "commitment:" + id
            related = Set(plan.assistance?.appliedRecurringIDs.filter { $0.value == id }.map(\.key) ?? [])
            removeCommitment(region: region.rawValue, id: id)
            lexicalContext.localeIdentifiersByField["amount." + id] = nil
        case let .accountIncluded(accountID, included, rowID):
            guard let account = accounts.first(where: { $0.id == accountID }), validNewBalanceID(rowID, accountID: accountID) else { return nil }
            item = "balance:" + accountID; newBalanceRowID = rowID
            setAccountIncluded(account, included: included)
        case let .manualBalance(accountID, text, rowID):
            guard let account = accounts.first(where: { $0.id == accountID }), validNewBalanceID(rowID, accountID: accountID),
                  !account.isHistoryOnly || selectedHistoryAccountIDs.contains(accountID) else { return nil }
            item = "balance:" + accountID
            let currentMoney = plan.balances.first { $0.accountID == accountID }?.money
            guard text != displayedInputText("balance." + accountID, fallback: currentMoney.map(exactText) ?? "") else { replayedNumericInput = true; break }
            newBalanceRowID = rowID
            editedLocale("balance." + accountID, inputLocaleIdentifier); setManualBalance(account, text: text)
        }
        if replayedNumericInput { errorMessage = beforeError; locale = beforeLocale }
        return Mutation(itemID: item, relatedOccurrenceIDs: related,
                        changed: scratchpad != before || lexicalContext != beforeLexical || selectedHistoryAccountIDs != beforeSelection,
                        salaryReceiptNeedsRevalidation: salaryReceiptNeedsRevalidation)
    }
    private func rows(in region: Region) -> [FundingPlanCommitment] { region == .qatar ? plan.qatarCommitments : plan.indiaCommitments }
    private func validNewBalanceID(_ id: String, accountID: String) -> Bool {
        plan.balances.contains { $0.accountID == accountID } || (!id.isEmpty && !hasRow(id))
    }
    /// Revalidates visible lexical input without replacing values/provenance or normalizing text.
    /// This is not complete untrusted packet/domain validation; the Mac apply path still owns that.
    mutating func validateRetainedInput() {
        validateVisibleDraft()
        // Preserve the original atomic rate/date edit validation, without turning an
        // unchanged public basis into a manual override during routine validation.
        if plan.referenceMode == .manual {
            setFX(rateText: rawText["fx.rate"] ?? "", dateText: rawText["fx.date"] ?? "")
        }
    }
    func moneyText(_ field: MoneyField) -> String {
        if let text = rawText[field.rawValue] { return text }
        let money: Money
        switch field {
        case .fixed: money = plan.expectedFixedEarnings
        case .variable: money = plan.expectedVariableEarnings
        case .deductions: money = plan.expectedDeductions
        case .fee: money = plan.configuredTransferFee
        case .investment: money = plan.plannedInvestment
        case .reserve: money = plan.keepInCBQ ?? Self.zeroQAR
        }
        return (try? money.canonicalDecimalString()) ?? ""
    }

    // Compare against current retained state, never a captured SwiftUI binding value.
    // This preserves unknown origin, provenance and untouched-zero state on replayed setters.
    func displayedInputText(_ key: String, fallback: String = "") -> String {
        let text = rawText[key] ?? fallback
        return untouchedZeroFields.contains(key) && text == "0" ? "" : text
    }
    private func exactText(_ money: Money) -> String { (try? money.canonicalDecimalString()) ?? "" }

    func amountInputText(_ key: String) -> String { displayedInputText(key) }

    private mutating func updateMoney(_ field: MoneyField, text: String) -> Bool {
        guard canEdit else { return false }
        guard plan.calculationVersion == .legacy || ![MoneyField.deductions, .investment].contains(field) else { return false }
        untouchedZeroFields.remove(field.rawValue)
        rawText[field.rawValue] = text

        guard let value = validatedMoney(field, text: text) else { return false }
        switch field {
        case .fixed: plan.expectedFixedEarnings = value; plan.expectedFixedProvenance = .manual
        case .variable: plan.expectedVariableEarnings = value; plan.expectedVariableProvenance = .manual
        case .deductions: plan.expectedDeductions = value; plan.expectedDeductionsProvenance = .manual
        case .fee: plan.configuredTransferFee = value; plan.configuredTransferFeeProvenance = .manual
        case .investment: plan.plannedInvestment = value; plan.plannedInvestmentProvenance = .manual
        case .reserve: plan.keepInCBQ = value
        }

        return true
    }

    private mutating func setFX(rateText: String, dateText: String) {
        guard canEdit else { return }
        let savedRateWithoutLocale = parseLocale(for: "fx.rate") == nil ? plan.planningFX?.inrPerQAR : nil
        let savedRateErrorWithoutLocale = parseLocale(for: "fx.rate") == nil ? fieldErrors["fx.rate"] : nil
        plan.referenceMode = .manual; plan.effectiveAlDarReference = nil
        plan.alDarReference = nil
        plan.planningFX = nil
        rawText["fx.rate"] = rateText; rawText["fx.date"] = dateText

        fieldErrors["fx.rate"] = nil; fieldErrors["fx.date"] = nil
        if rateText.isEmpty && dateText.isEmpty {
            plan.planningFX = nil
            if plan.calculationVersion == .budgetV1 { fieldErrors["fx.rate"] = "Enter a positive rate or choose Use Al Dar" }
            return
        }
        let rate = parseLocale(for: "fx.rate").flatMap({ try? PlannerInputCodec.rate(rateText, locale: $0) }) ?? savedRateWithoutLocale
        let date = try? StatementDate(canonical: dateText)
        if rate == nil { fieldErrors["fx.rate"] = "Enter a complete positive INR-per-QAR rate" }
        if let savedRateErrorWithoutLocale { fieldErrors["fx.rate"] = savedRateErrorWithoutLocale }
        if date == nil { fieldErrors["fx.date"] = "Enter the observation date as YYYY-MM-DD" }
        guard fieldErrors["fx.rate"] == nil, let rate, let date, let fx = try? FundingPlanFX(inrPerQAR: rate, observationDate: date) else { return }
        plan.planningFX = fx

    }

    private mutating func useSharedAlDar() {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return }
        plan.referenceMode = .alDar; plan.planningFX = nil; plan.alDarReference = nil
        plan.effectiveAlDarReference = availableAlDarQuote
        rawText["fx.rate"] = ""; rawText["fx.date"] = ""; fieldErrors["fx.rate"] = nil; fieldErrors["fx.date"] = nil

    }

    private mutating func addDeduction(id: String) {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return }
        let row = FundingPlanDeduction(id: id, label: "", money: Self.zeroQAR, recurs: true)
        plan.deductions.append(row); rawText["deduction.label.\(row.id)"] = ""; rawText["deduction.amount.\(row.id)"] = "0"
        untouchedZeroFields.insert("deduction.amount.\(row.id)"); fieldErrors["deduction.label.\(row.id)"] = "Enter a name"

    }

    private mutating func editDeduction(id: String, label: String? = nil, amount: String? = nil, recurs: Bool? = nil) {
        guard canEdit, let index = plan.deductions.firstIndex(where: { $0.id == id }) else { return }
        if let label {
            rawText["deduction.label.\(id)"] = label
            fieldErrors["deduction.label.\(id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a name of 1–240 characters" : nil
            plan.deductions[index].label = label
        }
        if let amount {
            let key = "deduction.amount.\(id)"; rawText[key] = amount; untouchedZeroFields.remove(key)
            if let money = parseLocale(for: key).flatMap({ try? PlannerInputCodec.money(amount, currency: "QAR", locale: $0) }), money.amount >= 0 {
                plan.deductions[index].money = money; fieldErrors[key] = nil
            } else { fieldErrors[key] = "Enter a deduction of zero or greater" }
        }
        if let recurs { plan.deductions[index].recurs = recurs }

    }

    private mutating func removeDeduction(id: String) {
        guard canEdit else { return }
        plan.deductions.removeAll { $0.id == id }
        for key in ["deduction.label.\(id)", "deduction.amount.\(id)"] { rawText[key] = nil; fieldErrors[key] = nil; untouchedZeroFields.remove(key) }

    }

    private mutating func setCommitmentDetails(region: String, id: String, recurs: Bool? = nil, temporary: Bool? = nil, remark: String? = nil) {
        guard canEdit else { return }
        var rows = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        if let recurs { rows[index].recurs = recurs; if !recurs { rows[index].temporaryCarryBasis = nil; preReductionBasis[id] = nil } }
        if let temporary {
            if temporary && rows[index].recurs && rows[index].temporaryCarryBasis == nil {
                rows[index].temporaryCarryBasis = preReductionBasis.removeValue(forKey: id) ?? rows[index].money
            }
            if !temporary {
                if let basis = rows[index].temporaryCarryBasis {
                    rows[index].money = basis
                    rawText["amount.\(id)"] = (try? basis.canonicalDecimalString()).map(localized) ?? ""
                    fieldErrors["amount.\(id)"] = nil
                }
                rows[index].temporaryCarryBasis = nil
            }
        }
        if let remark { rows[index].remark = String(remark.prefix(240)) }
        if region == "qatar" { plan.qatarCommitments = rows } else { plan.indiaCommitments = rows }

    }

    private mutating func setAccountIncluded(_ account: PlannerAccountInput, included: Bool) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        if account.isHistoryOnly {
            if included { selectedHistoryAccountIDs.insert(id) }
            else { selectedHistoryAccountIDs.remove(id) }
        }

        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].included = included
        } else {
            plan.balances.append(FundingPlanBalance(id: newBalanceRowID, accountID: id, nativeCurrency: account.nativeCurrency, included: included, money: nil, provenance: .manual))
        }

    }

    private mutating func setManualBalance(_ account: PlannerAccountInput, text: String) {
        guard canEdit else { return }
        guard let id = account.repositoryAccountId else { return }
        guard !account.isHistoryOnly || selectedHistoryAccountIDs.contains(id) else { return }
        unavailableCurrentBalanceAccountIDs.remove(id)
        let key = "balance.\(id)"
        untouchedZeroFields.remove(key)
        rawText[key] = text

        guard let money = parseLocale(for: key).flatMap({ try? PlannerInputCodec.money(text, currency: account.nativeCurrency.code, locale: $0) }) else {
            fieldErrors[key] = "Enter an exact \(account.nativeCurrency.code) balance"
            return
        }
        fieldErrors[key] = nil
        if let index = plan.balances.firstIndex(where: { $0.accountID == id }) {
            plan.balances[index].money = money
            plan.balances[index].provenance = .manual
            plan.balances[index].financialBalanceDate = nil
        } else {
            plan.balances.append(FundingPlanBalance(id: newBalanceRowID, accountID: id, nativeCurrency: account.nativeCurrency, included: false, money: money, provenance: .manual))
        }

    }

    private mutating func addCommitment(region: String, id: String) {
        guard canEdit else { return }

        let currency = region == "qatar" ? "QAR" : "INR"
        guard let zero = try? Money(canonicalDecimal: "0.00", currency: currency) else { return }
        let value = FundingPlanCommitment(id: id, label: "New commitment", money: zero, included: true, fundingAccountID: nil, provenance: .manual)
        rawText["label.\(value.id)"] = value.label
        rawText["amount.\(value.id)"] = localized("0.00")
        untouchedZeroFields.insert("amount.\(value.id)")
        if region == "qatar" { plan.qatarCommitments.append(value) }
        else { plan.indiaCommitments.append(value) }

    }

    private mutating func updateCommitment(region: String, id: String, label: String, amountText: String, included: Bool, fundingAccountID: String?, amountWasEdited: Bool = true) {
        guard canEdit else { return }
        if amountWasEdited { untouchedZeroFields.remove("amount.\(id)") }
        let currency = region == "qatar" ? "QAR" : "INR"
        rawText["label.\(id)"] = label; rawText["amount.\(id)"] = amountText

        fieldErrors["label.\(id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a label of 1–240 characters" : nil
        var values = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = values.firstIndex(where: { $0.id == id }) else { return }
        let preservesUnknownAmount = !amountWasEdited && parseLocale(for: "amount.\(id)") == nil
        let money = preservesUnknownAmount
            ? (fieldErrors["amount.\(id)"] == nil ? values[index].money : nil)
            : parseLocale(for: "amount.\(id)").flatMap({ try? PlannerInputCodec.money(amountText, currency: currency, locale: $0) })
        if !preservesUnknownAmount { fieldErrors["amount.\(id)"] = money == nil ? "Enter an exact \(currency) amount" : nil }
        if plan.calculationVersion == .budgetV1, let money,
           money.amount < 0 || (values[index].temporaryCarryBasis.map { money.amount > $0.amount } ?? false) {
            fieldErrors["amount.\(id)"] = "Enter a nonnegative remaining amount no greater than the recurring estimate"
            return
        }
        let changedValue = values[index].label != label || (money != nil && values[index].money != money)
        if amountWasEdited, let money, plan.calculationVersion == .budgetV1,
           values[index].recurs, values[index].temporaryCarryBasis == nil {
            if money.amount < values[index].money.amount, preReductionBasis[id] == nil {
                preReductionBasis[id] = values[index].money
            } else if let basis = preReductionBasis[id], money.amount >= basis.amount {
                preReductionBasis[id] = nil
            }
        }
        if fieldErrors["label.\(id)"] == nil { values[index].label = label }
        if let money { values[index].money = money }
        values[index].included = included
        values[index].fundingAccountID = fundingAccountID
        if changedValue { values[index].provenance = .manual }
        if region == "qatar" { plan.qatarCommitments = values } else { plan.indiaCommitments = values }

    }

    func isConfirmedRecurringRow(_ id: String) -> Bool {
        plan.assistance?.appliedRecurringIDs.values.contains(id) == true
    }

    private mutating func editCommitment(region: String, id: String, field: String, text: String) {
        guard field != "account" || !isConfirmedRecurringRow(id) else { return }
        guard let value = (region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments).first(where: { $0.id == id }) else { return }
        updateCommitment(region: region, id: id,
            label: field == "label" ? text : rawText["label.\(id)"] ?? value.label,
            amountText: field == "amount" ? text : rawText["amount.\(id)"] ?? "",
            included: field == "included" ? text == "true" : value.included,
            fundingAccountID: field == "account" ? (text.isEmpty ? nil : text) : value.fundingAccountID,
            amountWasEdited: field == "amount")
    }

    private mutating func removeCommitment(region: String, id: String) {
        guard canEdit else { return }
        preReductionBasis[id] = nil

        for key in ["label.\(id)", "amount.\(id)"] { rawText[key] = nil; fieldErrors[key] = nil; untouchedZeroFields.remove(key) }
        if region == "qatar" { plan.qatarCommitments.removeAll { $0.id == id } }
        else { plan.indiaCommitments.removeAll { $0.id == id } }
        for occurrenceID in plan.assistance?.appliedRecurringIDs.filter({ $0.value == id }).map(\.key) ?? [] {
            excludedRecurringOccurrenceIDs.insert(occurrenceID)
            plan.assistance?.appliedRecurringIDs[occurrenceID] = nil
            plan.assistance?.appliedRecurringPaid?[occurrenceID] = nil
        }
        plan.assistance?.billFundingAccounts?[id] = nil
        plan.assistance?.carriedBillDates?[id] = nil
        for index in plan.assistance?.datedAdjustments.indices ?? 0..<0 {
            if plan.assistance?.datedAdjustments[index].replacesCommitmentID == id { plan.assistance?.datedAdjustments[index].replacesCommitmentID = nil }
        }

    }

    private mutating func setBillDate(region: String, id: String, date: Date?, timeZone: TimeZone = .current) {
        guard canEdit, plan.calculationVersion == .budgetV1 else { return }
        var rows = region == "qatar" ? plan.qatarCommitments : plan.indiaCommitments
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        var due: StatementDate?
        if let date {
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let selectedMonth = parts.month, let day = parts.day,
                  let valid = try? StatementDate(year: year, month: selectedMonth, day: day) else {
                errorMessage = "Choose a valid bill date."; return
            }
            due = valid
        }
        if isConfirmedRecurringRow(id) {
            guard let due, due >= plan.recurringStart, due <= plan.recurringEnd else {
                errorMessage = "Choose a recurring payment date within \(plan.recurringStart.presentation)–\(plan.recurringEnd.presentation)."
                return
            }
        }
        rows[index].dueDate = due
        plan.assistance?.carriedBillDates?[id] = nil
        if region == "qatar" { plan.qatarCommitments = rows } else { plan.indiaCommitments = rows }

    }

    private func localized(_ text: String) -> String {
        var compact = text
        if compact.contains(".") { while compact.hasSuffix("0") { compact.removeLast() }; if compact.hasSuffix(".") { compact.removeLast() } }
        return compact.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }

    private mutating func validatedMoney(_ field: MoneyField, text: String) -> Money? {
        guard let inputLocale = parseLocale(for: field.rawValue) else { return nil }
        guard let value = try? PlannerInputCodec.money(text, currency: "QAR", locale: inputLocale) else {
            fieldErrors[field.rawValue] = "Enter an exact QAR amount with up to two decimals"
            return nil
        }
        guard ![MoneyField.fee, .reserve].contains(field) || value.amount >= 0 else {
            fieldErrors[field.rawValue] = field == .fee ? "Transfer fee must be zero or greater" : "Reserve must be zero or greater"
            return nil
        }
        fieldErrors[field.rawValue] = nil
        return value
    }

    private mutating func validateVisibleDraft() {
        for field in visibleMoneyFields {
            _ = validatedMoney(field, text: moneyText(field))
        }
        for row in plan.deductions {
            let label = rawText["deduction.label.\(row.id)"] ?? ""
            fieldErrors["deduction.label.\(row.id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a deduction name" : nil
            if let inputLocale = parseLocale(for: "deduction.amount.\(row.id)") {
                let value = try? PlannerInputCodec.money(rawText["deduction.amount.\(row.id)"] ?? "", currency: "QAR", locale: inputLocale)
                fieldErrors["deduction.amount.\(row.id)"] = value.map { $0.amount >= 0 } == true ? nil : "Enter a nonnegative deduction"
            }
        }
        // FX has no separate commit state; both fields were parsed together on every edit.
        for account in eligibleAccounts {
            if let id = account.repositoryAccountId, let text = rawText["balance.\(id)"], !text.isEmpty,
               let inputLocale = parseLocale(for: "balance.\(id)") {
                // Validation must not turn a captured or carried balance into a manual value.
                fieldErrors["balance.\(id)"] = (try? PlannerInputCodec.money(text, currency: account.nativeCurrency.code, locale: inputLocale)) == nil ? "Enter an exact balance" : nil
            }
        }
        for (region, values) in [("qatar", plan.qatarCommitments), ("india", plan.indiaCommitments)] {
            for value in values where value.isInAccountScope(excluding: excludedHistoryAccountIDs, fundingOverrides: plan.assistance?.billFundingAccounts) {
                let label = rawText["label.\(value.id)"] ?? ""
                fieldErrors["label.\(value.id)"] = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || label.count > 240 ? "Enter a label of 1–240 characters" : nil
                let amount = rawText["amount.\(value.id)"] ?? ""
                guard let inputLocale = parseLocale(for: "amount.\(value.id)") else { continue }
                let parsed = try? PlannerInputCodec.money(amount, currency: region == "qatar" ? "QAR" : "INR", locale: inputLocale)
                let valid = parsed.map { money in
                    plan.calculationVersion == .legacy || (money.amount >= 0 && (value.temporaryCarryBasis.map { money.amount <= $0.amount } ?? true))
                } ?? false
                fieldErrors["amount.\(value.id)"] = valid ? nil : "Enter a nonnegative amount within the remaining-payment basis"
            }
        }
    }
}
