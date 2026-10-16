import SwiftUI

private enum RuleAction {
    case categoryCreate, categoryDelete, transactionCategoryAssignment
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    var protectedAction: DevelopmentProtectedAction {
        switch self {
        case .categoryCreate: .categoryCreate
        case .categoryDelete: .categoryDelete
        case .transactionCategoryAssignment: .transactionCategoryAssignment
        }
    }
#endif
}

@MainActor private final class CategoryRuleDraftOwner { var isDirty = false }

/// Focused rule editing and explicit historical preview. The selected transaction
/// set is frozen when this sheet opens, so its counts and detail rows agree.
struct CategoryRulesView: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.appearsActive) private var appearsActive
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var categories = CategoryStore.shared
    @ObservedObject private var accounts = AccountStore.shared
    @ObservedObject private var session = CategoryAutomationSession.shared
    let transactions: [Transaction]
    var proposal: Transaction? = nil
    @State private var draft = Self.blankRule()
    @State private var baseline = Self.blankRule()
    @State private var previousVersion: Int?
    @State private var generation: ProviderGenerationToken?
    @State private var preview: CategoryHistoricalPreview?
    @State private var showUnchangedPreview = false
    @State private var isPreviewing = false
    @State private var isApplying = false
    @State private var message: String?
    @State private var showCategoryManagement = false
    @State private var newCategoryName = ""
    @State private var draftOwner = CategoryRuleDraftOwner()
    private enum EditorNavigation { case close, newRule, rule(String) }
    @State private var pendingNavigation: EditorNavigation?
    @State private var pendingDeletion: CategoryRule?
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pendingAction: (() -> Void)?
#endif

    private static func blankRule() -> CategoryRule {
        CategoryRule(id: UUID().uuidString, workspaceID: "default-workspace", name: "", version: 1,
            isEnabled: true, categoryID: "", accountID: nil, currency: nil, direction: nil,
            predicates: [.init(field: .narration, match: .contains, text: "")])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category rules").font(theme.typography.formTitle)
                    Text("Enabled rules apply to new imports. Review existing transactions below before applying rules to history.")
                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Button("Done") { requestNavigation(.close) }
                    .lfSecondaryAction()
                    .keyboardShortcut(.cancelAction)
                    .disabled(isApplying)
            }
            HSplitView {
                ruleList.frame(minWidth: 240, idealWidth: 290, maxWidth: 360)
                ScrollView { editor.padding(.leading, 16).padding(.trailing, 4) }
                    .frame(minWidth: 470, maxWidth: .infinity)
            }
            .disabled(isApplying)
            Divider()
            Text("Historical review · \(transactions.count) transactions from the list when this window opened. All enabled rules are checked; selecting a rule above only edits that rule.")
                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            HStack(spacing: 12) {
                Button("Preview rules on \(transactions.count) existing transactions", action: makePreview)
                    .lfSecondaryAction()
                    .accessibilityIdentifier("categoryRules.previewHistory")
                    .disabled(isPreviewing || isApplying || categories.snapshot.automation == nil || transactions.isEmpty)
                if isPreviewing || isApplying { ProgressView().controlSize(.small) }
                Spacer()
                if let preview {
                    Button("Apply reviewed results") { request(.transactionCategoryAssignment, action: applyPreview) }
                        .lfPrimaryAction()
                        .accessibilityIdentifier("categoryRules.applyHistory")
                        .disabled(preview.receipt.changedIDs.isEmpty || isPreviewing || isApplying)
                }
            }
            if let preview {
                VStack(alignment: .leading, spacing: 4) {
                    let receipt = preview.receipt
                    Text("\(receipt.changedIDs.count) records will change · \(receipt.unchangedIDs.count) unchanged · \(receipt.protectedIDs.count) manual or cleared choices protected")
                    Text(receipt.categorySummary)
                    Text(receipt.metadataSummary)
                    Text("A record can have more than one effect; the record count counts it once. Category changes do not confirm income or movement relationships.")
                }.font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                Toggle("Show \(preview.unchangedCount) unchanged results", isOn: $showUnchangedPreview)
                    .font(theme.typography.formCaption)
                previewList(preview).frame(minHeight: 140, maxHeight: 230)
            }
            if let message { Text(message).font(theme.typography.formCaption).foregroundStyle(LFTheme.warning) }
            if let status = session.message {
                HStack {
                    Text(status).font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                    if !(categories.snapshot.automation?.pendingIDs.isEmpty ?? true) {
                        Button("Retry rules") { session.retry() }.lfSecondaryAction().disabled(session.isWorking)
                    }
                }
            }
        }
        .padding(22)
        .frame(minWidth: 850, idealWidth: 1120, maxWidth: .infinity, minHeight: 590, idealHeight: 760, maxHeight: .infinity)
        .foregroundStyle(theme.palette.primaryText)
        .background(theme.palette.contentSurface)
        .interactiveDismissDisabled(isApplying || draft != baseline)
        .onAppear {
            generation = categories.snapshot.providerGeneration
            resetEditor()
            if let proposal {
                // A proposed reusable rule starts portable. Narrow account or
                // currency scope remains an explicit editor choice.
                draft.accountID = nil; draft.currency = nil
                draft.direction = proposal.cardLiabilityEffect?.rawValue ?? (proposal.debitMoney != nil ? "debit" : "credit")
                draft.predicates = [.init(field: .narration, match: .exact, text: proposal.description)]
                draft.categoryID = proposal.repositoryTransactionId.flatMap { categories.snapshot.assignments[$0] } ?? ""
                draft.name = ""
            }
            let owner = draftOwner
            DatabaseActivityGate.shared.registerDraftOwner(owner) { [weak owner] in owner?.isDirty == true }
        }
        .onChange(of: draft) { _, _ in draftOwner.isDirty = draft != baseline }
        .onChange(of: categories.snapshot.rulesForDisplay) { _, _ in preview = nil }
        .onChange(of: categories.snapshot.assignments) { _, _ in preview = nil }
        .onChange(of: categories.snapshot.automation?.intents) { _, _ in preview = nil }
        .onChange(of: categories.snapshot.automation?.work) { _, _ in preview = nil }
        .onChange(of: categories.snapshot.automation?.spendingIntents) { _, _ in preview = nil }
        .onChange(of: categories.snapshot.automation?.spendingContexts) { _, _ in preview = nil }
        .onChange(of: categories.snapshot.providerGeneration) { _, value in
            if value != generation { preview = nil; message = "The ledger changed. Close this editor and reopen it before saving." }
        }
        .sheet(isPresented: $showCategoryManagement) {
            VStack(alignment: .trailing) {
                Button("Done") { showCategoryManagement = false }.lfSecondaryAction().keyboardShortcut(.cancelAction)
                ScrollView { CategoryManagementView() }
            }.padding(20).frame(minWidth: 540, minHeight: 430)
        }
        .confirmationDialog("Discard the unsaved rule?", isPresented: Binding(
            get: { pendingNavigation != nil }, set: { if !$0 { pendingNavigation = nil } }),
            titleVisibility: .visible, presenting: pendingNavigation) { navigation in
            Button("Discard", role: .destructive) { pendingNavigation = nil; navigate(navigation) }
            Button("Keep editing", role: .cancel) { pendingNavigation = nil }
        }
        .confirmationDialog("Delete this rule?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
            Button("Delete rule", role: .destructive) {
                guard let rule = pendingDeletion else { return }
                request(.categoryDelete) {
                    perform {
                        guard let generation else { throw CategoryAutomationError.unavailable }
                        try CategoryManagementCoordinator().deleteRule(rule, expectedGeneration: generation)
                        pendingDeletion = nil; resetEditor()
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { Text("Existing categories and spending treatment stay as they are. This rule will no longer apply to future imports.") }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        .confirmationDialog(DevelopmentProfileAcknowledgementPresentation.title, isPresented: Binding(get: { challenge != nil }, set: { if !$0 { challenge = nil; pendingAction = nil } }), titleVisibility: .visible) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                guard let challenge else { return }
                if DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge) == .granted {
                    let action = pendingAction; self.challenge = nil; pendingAction = nil; action?()
                }
            }
            Button("Cancel", role: .cancel) { challenge = nil; pendingAction = nil }
        } message: { Text(DevelopmentProfileAcknowledgementPresentation.message) }
#endif
    }

    private var ruleList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved rules").font(theme.typography.formHeading)
                Spacer()
                Button { requestNavigation(.newRule) } label: { Label("New rule", systemImage: "plus") }
                    .lfSecondaryAction().help("New category rule")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(categories.snapshot.rulesForDisplay) { rule in
                        Button { requestNavigation(.rule(rule.id)) } label: {
                            HStack(alignment: .top) {
                                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.name).font(theme.typography.body.weight(.medium))
                                    Text((categories.categories.first { $0.id == rule.categoryID }?.name ?? "Unavailable category") + " · v\(rule.version)")
                                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                                    if rule.bankExpenseAction == .expense {
                                        Text("Bank outflows count as spending").font(theme.typography.formCaption)
                                            .foregroundStyle(theme.palette.secondaryText)
                                    }
                                }
                                Spacer()
                            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.interaction.dataRow(selected: draft.id == rule.id, active: appearsActive))
                                .contentShape(Rectangle())
                        }.buttonStyle(LFPlainActionStyle())
                            .accessibilityAddTraits(draft.id == rule.id ? .isSelected : [])
                        Divider()
                    }
                    if categories.snapshot.rulesForDisplay.isEmpty {
                        Text("Create a rule using original narration or reference text. All its conditions must match.")
                            .font(theme.typography.body).foregroundStyle(theme.palette.secondaryText).padding(.vertical, 12)
                    }
                }
            }
            Button("Manage categories") { showCategoryManagement = true }.lfSecondaryAction()
        }.padding(.trailing, 14)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(previousVersion == nil ? "New rule" : "Edit rule").font(theme.typography.formHeading); Spacer(); Toggle("Enabled", isOn: $draft.isEnabled) }
            TextField("Rule name", text: $draft.name).textFieldStyle(.roundedBorder)
            Picker("Assign category", selection: $draft.categoryID) {
                Text("Choose a category").tag("")
                ForEach(categories.activeCategories) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu).tint(theme.palette.primaryText).font(theme.typography.button)
            if categories.activeCategories.isEmpty {
                HStack {
                    TextField("New category", text: $newCategoryName).textFieldStyle(.roundedBorder)
                    Button("Create") { request(.categoryCreate) { perform { _ = try CategoryManagementCoordinator().create(name: newCategoryName); newCategoryName = "" } } }.lfSecondaryAction()
                }
            }
            LFAccountPicker(label: "Account", placeholder: "Any account",
                selection: Binding(get: { draft.accountID ?? "" }, set: { draft.accountID = $0.isEmpty ? nil : $0 }),
                options: accounts.accounts.filter { $0.repositoryAccountId != nil }.map {
                    .init(id: $0.repositoryAccountId!, title: $0.preferredDisplayName, detail: $0.selectionContext)
                })
            HStack(spacing: 16) {
                Picker("Currency", selection: $draft.currency) {
                    Text("Any").tag(String?.none)
                    ForEach(Array(Set(transactions.map(\.currency))).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                }
                .pickerStyle(.menu).tint(theme.palette.primaryText).font(theme.typography.button)
                Picker("Direction", selection: $draft.direction) {
                    Text("Any").tag(String?.none)
                    Text("Bank debit").tag(Optional("debit")); Text("Bank credit").tag(Optional("credit"))
                    Text("Card charge").tag(Optional("card_increase_owed")); Text("Card credit").tag(Optional("card_decrease_owed"))
                }
                .pickerStyle(.menu).tint(theme.palette.primaryText).font(theme.typography.button)
            }
            if categories.snapshot.automation?.supportsSpendingIntent == true {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Count matching bank outflows as spending", isOn: Binding(
                        get: { draft.bankExpenseAction == .expense },
                        set: { draft.bankExpenseAction = $0 ? .expense : nil }))
                        .toggleStyle(.checkbox)
                    Text("Applies to eligible bank debits. Manual categories and clears do not change this treatment; reviewed transfers and source exclusions keep their meaning.")
                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                }
            }
            Divider()
            Text("Match every condition").font(theme.typography.formHeading)
            ForEach(draft.predicates.indices, id: \.self) { index in
                HStack {
                    Picker("Source field", selection: $draft.predicates[index].field) {
                        Text("Narration").tag(CategoryTextPredicate.Field.narration)
                        Text("Reference").tag(CategoryTextPredicate.Field.reference)
                            .disabled(draft.predicates[index].match == .doesNotContain)
                    }.labelsHidden().frame(width: 120)
                        .pickerStyle(.menu).tint(theme.palette.primaryText).font(theme.typography.button)
                    Picker("Match", selection: $draft.predicates[index].match) {
                        Text("Contains").tag(CategoryTextPredicate.Match.contains); Text("Is exactly").tag(CategoryTextPredicate.Match.exact)
                        if categories.snapshot.automation?.supportsSpendingIntent == true {
                            Text("Does not contain").tag(CategoryTextPredicate.Match.doesNotContain)
                                .disabled(draft.predicates[index].field != .narration)
                        }
                    }.labelsHidden().frame(minWidth: 108, idealWidth: 150)
                        .pickerStyle(.menu).tint(theme.palette.primaryText).font(theme.typography.button)
                    TextField("Source text", text: $draft.predicates[index].text).textFieldStyle(.roundedBorder)
                    Button { draft.predicates.remove(at: index) } label: { Image(systemName: "minus.circle") }
                        .lfIconAction().accessibilityLabel("Remove condition")
                        .disabled(draft.predicates.count == 1).help("Remove condition")
                }
            }
            Button { draft.predicates.append(.init(field: .narration, match: .contains, text: "")) } label: {
                Label("Add condition", systemImage: "plus")
            }.lfSecondaryAction().disabled(draft.predicates.count >= 12)
            Text("All conditions must match, including exclusions. Keep a positive narration or reference condition. Saving changes future imports; preview before applying to history.")
                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            HStack {
                Button("Save rule") { request(.categoryCreate, action: saveRule) }.lfPrimaryAction()
                if previousVersion != nil { Button("Delete rule", role: .destructive) { pendingDeletion = categories.snapshot.rulesForDisplay.first { $0.id == draft.id } }.lfSecondaryAction() }
                Spacer()
            }
        }
    }

    private func previewList(_ value: CategoryHistoricalPreview) -> some View {
        let byID = Dictionary(uniqueKeysWithValues: transactions.compactMap { transaction in transaction.repositoryTransactionId.map { ($0, transaction) } })
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(value.decisions.filter { showUnchangedPreview || !value.isUnchanged($0) }.sorted {
                    let left = byID[$0.transactionID]?.statementDate?.canonical ?? ""
                    let right = byID[$1.transactionID]?.statementDate?.canonical ?? ""
                    return left == right ? $0.transactionID < $1.transactionID : left > right
                }, id: \.transactionID) { decision in
                    if let transaction = byID[decision.transactionID] {
                        DisclosureGroup {
                            Text(transaction.description).textSelection(.enabled)
                            Text(decision.explanation).foregroundStyle(theme.palette.secondaryText)
                            Text("Current: " + (value.assignments[decision.transactionID].flatMap { id in categories.categories.first { $0.id == id }?.name } ?? "Uncategorized"))
                            if value.removesCategory(decision) {
                                Text("Applying these results will remove the automatic category.")
                            }
                            if let spending = decision.spending {
                                Text("Spending: " + spending.explanation).foregroundStyle(theme.palette.secondaryText)
                                if spending.context?.sourceEligible == true, spending.context?.protectsInterpretation == false {
                                    let suppressed = value.spendingIntents[decision.transactionID]?.kind == .deliberatelySuppressed
                                    Button(suppressed ? "Allow automatic spending treatment" : "Disable automatic spending treatment") {
                                        request(.transactionCategoryAssignment) {
                                            setSpendingSuppressed(!suppressed, transactionID: decision.transactionID,
                                                expected: value.spendingIntents[decision.transactionID])
                                        }
                                    }
                                    .disabled(isApplying)
                                    .help(suppressed ? "Remove this transaction's opt-out, then preview rules to apply treatment." : "Keep this transaction out of automatic spending treatment without changing its category.")
                                }
                            }
                        } label: {
                            HStack {
                                Text(transaction.statementDate?.presentation ?? "Date unavailable").frame(width: 84, alignment: .leading)
                                Text(accounts.accounts.first { $0.repositoryAccountId == transaction.repositoryAccountId }?.preferredDisplayName ?? transaction.account)
                                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text(transaction.signedAmountDisplay).monospacedDigit().fixedSize(horizontal: true, vertical: false)
                                    .frame(minWidth: 140, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(value.removesCategory(decision) ? "Remove category" : (decision.categoryID.flatMap { id in categories.categories.first { $0.id == id }?.name } ?? decision.outcome.displayTitle))
                                    if decision.spending?.changesIntent == true {
                                        Text(decision.spending?.removesIntent == true ? "Remove spending treatment" : "Count as spending")
                                            .foregroundStyle(theme.palette.secondaryText)
                                    }
                                }.frame(width: 185, alignment: .leading)
                            }
                        }.padding(.vertical, 6).font(theme.typography.formCaption)
                        Divider()
                    }
                }
            }
        }
    }

    private func requestNavigation(_ navigation: EditorNavigation) {
        guard !isApplying else { return }
        if case .rule(let id) = navigation, id == draft.id { return }
        if draft != baseline { pendingNavigation = navigation }
        else { navigate(navigation) }
    }

    private func navigate(_ navigation: EditorNavigation) {
        switch navigation {
        case .close: dismiss()
        case .newRule: resetEditor()
        case .rule(let id):
            guard categories.snapshot.providerGeneration == generation else {
                message = "The ledger changed. Close this editor and reopen it before saving."
                return
            }
            guard let rule = categories.snapshot.rulesForDisplay.first(where: { $0.id == id }) else {
                message = "That rule is no longer available. Your current entries are unchanged."
                return
            }
            load(rule)
        }
    }

    private func resetEditor() { let blank = Self.blankRule(); draft = blank; baseline = blank; previousVersion = nil; draftOwner.isDirty = false }
    private func load(_ rule: CategoryRule) { draft = rule; baseline = rule; previousVersion = rule.version; draftOwner.isDirty = false }
    private func saveRule() {
        perform {
            guard let generation else { throw CategoryAutomationError.unavailable }
            var value = draft; value.version = (previousVersion ?? 0) + 1
            try CategoryManagementCoordinator().saveRule(value, previousVersion: previousVersion, expectedGeneration: generation)
            load(value); preview = nil
        }
    }
    private func makePreview() {
        guard let metadata = categories.snapshot.automation else { return }
        let snapshot = categories.snapshot
        let ids = Set(transactions.compactMap(\.repositoryTransactionId))
        let inputs = CategoryAutomationSession.inputs(transactions: transactions, selectedIDs: ids)
        let active = Set(snapshot.activeCategories.map(\.id))
        isPreviewing = true; message = nil
        Task {
            let result = await Task.detached(priority: .utility) {
                CategoryEvaluation.evaluate(inputs: inputs, snapshot: metadata, assignments: snapshot.assignments, activeCategoryIDs: active)
            }.value
            isPreviewing = false
            guard categories.snapshot.providerGeneration == generation, snapshot.rulesForDisplay == categories.snapshot.rulesForDisplay,
                  snapshot.assignments == categories.snapshot.assignments, metadata.intents == categories.snapshot.automation?.intents,
                  metadata.spendingIntents == categories.snapshot.automation?.spendingIntents,
                  metadata.spendingContexts == categories.snapshot.automation?.spendingContexts,
                  metadata.work == categories.snapshot.automation?.work else {
                message = "The ledger or rules changed. Create a fresh preview."; return
            }
            preview = CategoryHistoricalPreview(evaluation: result, assignments: snapshot.assignments, intents: metadata.intents,
                spendingIntents: metadata.spendingIntents, spendingContexts: metadata.spendingContexts,
                work: metadata.work, importSessionIDs: Dictionary(transactions.compactMap { transaction in
                    guard let id = transaction.repositoryTransactionId, let session = transaction.repositoryImportSessionId else { return nil }
                    return (id, session)
                }, uniquingKeysWith: { first, _ in first }))
        }
    }
    private func applyPreview() {
        guard !isApplying else { return }
        do {
            guard let preview, let generation, let metadata = categories.snapshot.automation,
                  preview.matches(assignments: categories.snapshot.assignments, intents: metadata.intents,
                    spendingIntents: metadata.spendingIntents, spendingContexts: metadata.spendingContexts) else { throw CategoryAutomationError.stalePreview }
            isApplying = true; message = nil
            Task {
                defer { isApplying = false }
                do {
                    let receipt = try await CategoryManagementCoordinator().applyReviewedEvaluation(preview, expectedGeneration: generation)
                    self.preview = nil; message = "Saved reviewed results. " + receipt.summary + ". " + receipt.categorySummary + ". " + receipt.metadataSummary
                } catch {
                    message = (error as? CategoryAutomationError)?.localizedDescription ?? CategoryManagementPresentation.message(for: error)
                }
            }
        } catch {
            message = (error as? CategoryAutomationError)?.localizedDescription ?? CategoryManagementPresentation.message(for: error)
        }
    }
    private func setSpendingSuppressed(_ suppressed: Bool, transactionID: String, expected: TransactionSpendingIntent?) {
        perform {
            guard let generation else { throw CategoryAutomationError.unavailable }
            _ = try CategoryManagementCoordinator().setSpendingSuppressed(suppressed, transactionID: transactionID,
                expected: expected, expectedGeneration: generation)
            preview = nil
            message = suppressed ? "Automatic spending treatment is disabled for this transaction. Its category is unchanged." :
                "Automatic spending treatment is available again. Preview the rules before applying it to this transaction."
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() }
        catch { message = (error as? CategoryAutomationError)?.localizedDescription ?? CategoryManagementPresentation.message(for: error) }
    }
    private func request(_ action: RuleAction, action operation: @escaping () -> Void) {
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        switch DevelopmentProfileAcknowledgementGate.shared.authorization(for: action.protectedAction) {
        case .allowed: operation()
        case .acknowledgementRequired(let value): challenge = value; pendingAction = operation
        case .developmentDatabaseUnavailable: message = "The development database is unavailable."
        }
#else
        operation()
#endif
    }
}

private extension CategorySnapshot {
    var rulesForDisplay: [CategoryRule] { automation?.rules ?? [] }
}
extension CategoryImportWork.Outcome {
    var displayTitle: String {
        switch self {
        case .pending: "Waiting"
        case .assigned: "Assigned"
        case .noMatch: "No match"
        case .conflict: "Conflicting rules"
        case .protected: "Manual choice kept"
        case .retryable: "Retry needed"
        }
    }
}
