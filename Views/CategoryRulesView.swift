import SwiftUI

private enum RuleAction {
    case categoryCreate, categoryDelete, transactionCategoryAssignment
#if DEBUG
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
    @State private var preview: CategoryEvaluation?
    @State private var showUnchangedPreview = false
    @State private var isPreviewing = false
    @State private var message: String?
    @State private var showCategoryManagement = false
    @State private var newCategoryName = ""
    @State private var draftOwner = CategoryRuleDraftOwner()
    @State private var confirmClose = false
    @State private var pendingDeletion: CategoryRule?
#if DEBUG
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
                    Text("New imports use enabled rules. Your manual categories and clears always stay in place.")
                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                }
                Spacer()
                Button("Done") { if draftOwner.isDirty { confirmClose = true } else { dismiss() } }
                    .keyboardShortcut(.cancelAction)
            }
            HSplitView {
                ruleList.frame(minWidth: 240, idealWidth: 290, maxWidth: 360)
                ScrollView { editor.padding(.leading, 16).padding(.trailing, 4) }
                    .frame(minWidth: 470, maxWidth: .infinity)
            }
            Divider()
            HStack(spacing: 12) {
                Button("Preview rules on \(transactions.count) shown transactions", action: makePreview)
                    .disabled(isPreviewing || categories.snapshot.automation == nil || transactions.isEmpty)
                if isPreviewing { ProgressView().controlSize(.small) }
                Spacer()
                if let preview {
                    Text("\(preview.decisions.filter { $0.outcome == .assigned }.count) assignments · \(preview.decisions.filter { $0.outcome == .conflict }.count) conflicts")
                        .font(theme.typography.formCaption)
                    Button("Apply reviewed results") { request(.transactionCategoryAssignment, action: applyPreview) }
                        .buttonStyle(.borderedProminent)
                        .disabled(preview.decisions.isEmpty)
                }
            }
            if let preview {
                Toggle("Show \(preview.decisions.filter { $0.outcome == .noMatch || $0.outcome == .protected }.count) unchanged results", isOn: $showUnchangedPreview)
                    .font(theme.typography.formCaption)
                previewList(preview).frame(minHeight: 140, maxHeight: 230)
            }
            if let message { Text(message).font(theme.typography.formCaption).foregroundStyle(LFTheme.warning) }
            if let status = session.message {
                HStack {
                    Text(status).font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                    if !(categories.snapshot.automation?.pendingIDs.isEmpty ?? true) {
                        Button("Retry categories") { session.retry() }.disabled(session.isWorking)
                    }
                }
            }
        }
        .padding(22)
        .frame(minWidth: 850, idealWidth: 1120, maxWidth: .infinity, minHeight: 590, idealHeight: 760, maxHeight: .infinity)
        .foregroundStyle(theme.palette.primaryText)
        .background(theme.palette.contentSurface)
        .onAppear {
            generation = categories.snapshot.providerGeneration
            resetEditor()
            if let proposal {
                draft.accountID = proposal.repositoryAccountId; draft.currency = proposal.currency
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
        .onChange(of: categories.snapshot.providerGeneration) { _, value in
            if value != generation { preview = nil; message = "The ledger changed. Close this editor and reopen it before saving." }
        }
        .sheet(isPresented: $showCategoryManagement) {
            VStack(alignment: .trailing) {
                Button("Done") { showCategoryManagement = false }.keyboardShortcut(.cancelAction)
                ScrollView { CategoryManagementView() }
            }.padding(20).frame(minWidth: 540, minHeight: 430)
        }
        .confirmationDialog("Discard the unsaved rule?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
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
        } message: { Text("Existing categories stay as they are. This rule will no longer match future imports.") }
#if DEBUG
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
            HStack { Text("Saved rules").font(theme.typography.formHeading); Spacer(); Button { resetEditor() } label: { Image(systemName: "plus") }.help("New category rule") }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(categories.snapshot.rulesForDisplay) { rule in
                        Button { load(rule) } label: {
                            HStack(alignment: .top) {
                                Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.name).font(theme.typography.body.weight(.medium))
                                    Text((categories.categories.first { $0.id == rule.categoryID }?.name ?? "Unavailable category") + " · v\(rule.version)")
                                        .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
                                }
                                Spacer()
                            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(draft.id == rule.id ? theme.palette.dataSelection : Color.clear)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                    if categories.snapshot.rulesForDisplay.isEmpty {
                        Text("Create a rule using original narration or reference text. All its conditions must match.")
                            .font(theme.typography.body).foregroundStyle(theme.palette.secondaryText).padding(.vertical, 12)
                    }
                }
            }
            Button("Manage categories") { showCategoryManagement = true }
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
            if categories.activeCategories.isEmpty {
                HStack {
                    TextField("New category", text: $newCategoryName).textFieldStyle(.roundedBorder)
                    Button("Create") { request(.categoryCreate) { perform { _ = try CategoryManagementCoordinator().create(name: newCategoryName); newCategoryName = "" } } }
                }
            }
            Picker("Account", selection: $draft.accountID) {
                Text("Any account").tag(String?.none)
                ForEach(accounts.accounts.filter { $0.repositoryAccountId != nil }) { account in
                    Text([account.preferredDisplayName,
                          account.sourceAccountLabel ?? account.identitySummaries.first?.redactedValue,
                          account.nativeCurrency.code].compactMap { $0 }.joined(separator: " · "))
                        .tag(account.repositoryAccountId)
                }
            }
            HStack(spacing: 16) {
                Picker("Currency", selection: $draft.currency) {
                    Text("Any").tag(String?.none)
                    ForEach(Array(Set(transactions.map(\.currency))).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                }
                Picker("Direction", selection: $draft.direction) {
                    Text("Any").tag(String?.none)
                    Text("Bank debit").tag(Optional("debit")); Text("Bank credit").tag(Optional("credit"))
                    Text("Card charge").tag(Optional("card_increase_owed")); Text("Card credit").tag(Optional("card_decrease_owed"))
                }
            }
            Divider()
            Text("Match every condition").font(theme.typography.formHeading)
            ForEach(draft.predicates.indices, id: \.self) { index in
                HStack {
                    Picker("Source field", selection: $draft.predicates[index].field) {
                        Text("Narration").tag(CategoryTextPredicate.Field.narration); Text("Reference").tag(CategoryTextPredicate.Field.reference)
                    }.labelsHidden().frame(width: 120)
                    Picker("Match", selection: $draft.predicates[index].match) {
                        Text("Contains").tag(CategoryTextPredicate.Match.contains); Text("Is exactly").tag(CategoryTextPredicate.Match.exact)
                    }.labelsHidden().frame(width: 108)
                    TextField("Source text", text: $draft.predicates[index].text).textFieldStyle(.roundedBorder)
                    Button { draft.predicates.remove(at: index) } label: { Image(systemName: "minus.circle") }
                        .disabled(draft.predicates.count == 1).help("Remove condition")
                }
            }
            Button("Add condition") { draft.predicates.append(.init(field: .narration, match: .contains, text: "")) }.disabled(draft.predicates.count >= 12)
            Text("Matching ignores letter case. Conflicting categories stay for review. Saving changes future imports; use the preview below to apply rules to history.")
                .font(theme.typography.formCaption).foregroundStyle(theme.palette.secondaryText)
            HStack {
                Button("Save rule") { request(.categoryCreate, action: saveRule) }.buttonStyle(.borderedProminent)
                if previousVersion != nil { Button("Delete rule", role: .destructive) { pendingDeletion = categories.snapshot.rulesForDisplay.first { $0.id == draft.id } } }
                Spacer()
            }
        }
    }

    private func previewList(_ value: CategoryEvaluation) -> some View {
        let byID = Dictionary(uniqueKeysWithValues: transactions.compactMap { transaction in transaction.repositoryTransactionId.map { ($0, transaction) } })
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(value.decisions.filter { showUnchangedPreview || ($0.outcome != .noMatch && $0.outcome != .protected) }.sorted {
                    let left = byID[$0.transactionID]?.statementDate?.canonical ?? ""
                    let right = byID[$1.transactionID]?.statementDate?.canonical ?? ""
                    return left == right ? $0.transactionID < $1.transactionID : left > right
                }, id: \.transactionID) { decision in
                    if let transaction = byID[decision.transactionID] {
                        DisclosureGroup {
                            Text(transaction.description).textSelection(.enabled)
                            Text(decision.explanation).foregroundStyle(theme.palette.secondaryText)
                            Text("Current: " + (categories.category(forTransactionID: decision.transactionID)?.name ?? "Uncategorized"))
                        } label: {
                            HStack {
                                Text(transaction.statementDate?.presentation ?? "Date unavailable").frame(width: 84, alignment: .leading)
                                Text(transaction.account).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text(transaction.signedAmountDisplay).monospacedDigit().frame(width: 140, alignment: .trailing)
                                Text(decision.categoryID.flatMap { id in categories.categories.first { $0.id == id }?.name } ?? decision.outcome.displayTitle).frame(width: 155, alignment: .leading)
                            }
                        }.padding(.vertical, 6).font(theme.typography.formCaption)
                        Divider()
                    }
                }
            }
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
            guard categories.snapshot.providerGeneration == generation, snapshot.rulesForDisplay == categories.snapshot.rulesForDisplay else {
                message = "The ledger or rules changed. Create a fresh preview."; return
            }
            preview = result
        }
    }
    private func applyPreview() {
        perform {
            guard let preview, let generation else { throw CategoryAutomationError.stalePreview }
            _ = try CategoryManagementCoordinator().applyEvaluation(preview, historical: true, expectedGeneration: generation)
            self.preview = nil; message = "Reviewed category results saved. Manual choices were preserved."
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() }
        catch { message = (error as? CategoryAutomationError)?.localizedDescription ?? CategoryManagementPresentation.message(for: error) }
    }
    private func request(_ action: RuleAction, action operation: @escaping () -> Void) {
#if DEBUG
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
