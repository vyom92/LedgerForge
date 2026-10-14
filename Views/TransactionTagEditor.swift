import SwiftUI

@MainActor private final class TransactionTagDraftOwner { var isDirty = false }

private enum TransactionTagMutation {
    case save(TransactionTagDefinition, replacing: TransactionTagDefinition?)
    case remove(TransactionTagDefinition, expectedTransactionIDs: Set<String>)
    case membership(TransactionTagDefinition, transactionIDs: Set<String>, attached: Bool, expected: Set<String>)
}

private struct TransactionTagDeletion {
    let tag: TransactionTagDefinition
    let transactionIDs: Set<String>
}

/// The presenting transaction view freezes canonical IDs for this scoped
/// editor. Membership actions are explicit; creating a tag does not attach it.
struct TransactionTagEditor: View {
    @Environment(\.lfTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tagStore: TransactionTagStore
    @ObservedObject private var availability: ApplicationAvailability
    private let coordinator: TransactionTagManaging
    private let transactionIDs: Set<String>
    private let workspaceID: String
    @State private var generation: ProviderGenerationToken?
    @State private var newName = ""
    @State private var editingTag: TransactionTagDefinition?
    @State private var editedName = ""
    @State private var pendingDeletion: TransactionTagDeletion?
    @State private var message: String?
    @State private var refreshRequired = false
    @State private var confirmClose = false
    @State private var draftOwner = TransactionTagDraftOwner()
    @FocusState private var focusedField: Field?
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
    @State private var challenge: DevelopmentProfileAcknowledgementChallenge?
    @State private var pendingMutation: TransactionTagMutation?
#endif

    private enum Field: Hashable { case newName, rename }

    @MainActor
    init(transactionIDs: Set<String>, workspaceID: String = "default-workspace",
         tagStore: TransactionTagStore? = nil, coordinator: TransactionTagManaging? = nil,
         availability: ApplicationAvailability? = nil) {
        let store = tagStore ?? .shared
        self.transactionIDs = transactionIDs
        self.workspaceID = workspaceID
        self.tagStore = store
        self.availability = availability ?? .shared
        self.coordinator = coordinator ?? TransactionTagCoordinator(tagStore: store)
    }

    private var currentSnapshot: TransactionTagSnapshot? {
        guard let snapshot = tagStore.snapshot, snapshot.workspaceID == workspaceID else { return nil }
        return snapshot
    }

    private var canEdit: Bool {
        availability.permitsMutation && generation != nil && generation == availability.generation &&
        generation == tagStore.generation && currentSnapshot != nil && !refreshRequired
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            HStack(alignment: .top, spacing: theme.spacing.controlGap) {
                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    Text("Tags").font(theme.typography.formTitle)
                    Text(transactionIDs.isEmpty
                         ? "Create and manage your context labels."
                         : "Add or remove context labels for \(transactionIDs.count) selected \(transactionIDs.count == 1 ? "transaction" : "transactions").")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: theme.spacing.controlGap)
                Button("Done", action: close)
                    .lfSecondaryAction()
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: theme.spacing.small) {
                Text("New tag").font(theme.typography.formHeading)
                HStack(spacing: theme.spacing.controlGap) {
                    TextField("Tag name", text: $newName)
                        .lfTextField()
                        .focused($focusedField, equals: .newName)
                        .onSubmit(create)
                        .accessibilityLabel("New tag name")
                    Button("Create", action: create)
                        .lfPrimaryAction()
                        .disabled(!canEdit || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(!canEdit)

            Divider().overlay(theme.palette.divider)

            if let snapshot = currentSnapshot {
                if snapshot.definitions.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Text("No tags yet").font(theme.typography.formHeading)
                        Text("Create a label above, then add it to your selected transactions.")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(snapshot.definitions) { tag in
                                tagRow(tag, snapshot: snapshot)
                                    .padding(.vertical, theme.spacing.controlGap)
                                if tag.id != snapshot.definitions.last?.id {
                                    Divider().overlay(theme.palette.divider)
                                }
                            }
                        }
                        .padding(.trailing, theme.spacing.small)
                    }
                    .frame(minHeight: 160, idealHeight: 300, maxHeight: 440)
                }
            } else {
                Text("Tags are unavailable for the active ledger.")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            }

            if let message {
                Text(message)
                    .font(theme.typography.formCaption)
                    .foregroundStyle(LFTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if refreshRequired {
                Button("Retry refresh", action: retryRefresh).lfSecondaryAction()
            }
        }
        .padding(22)
        .frame(minWidth: 540, idealWidth: 660, maxWidth: 800)
        .foregroundStyle(theme.palette.primaryText)
        .background(theme.palette.contentSurface)
        .onAppear {
            generation = tagStore.generation
            if let generation, CategoryReconciliationGate.shared.isBlocked(for: generation) {
                refreshRequired = true
                message = TransactionTagError.refreshRequired.localizedDescription
            }
            let owner = draftOwner
            DatabaseActivityGate.shared.registerDraftOwner(owner) { [weak owner] in owner?.isDirty == true }
        }
        .onChange(of: newName) { _, _ in updateDraftState() }
        .onChange(of: editingTag) { _, _ in updateDraftState() }
        .onChange(of: editedName) { _, _ in updateDraftState() }
        .onChange(of: tagStore.generation) { _, value in
            if value != generation {
                pendingDeletion = nil
                message = "The active ledger changed. Close Tags and reopen it from your current selection."
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
                challenge = nil
                pendingMutation = nil
#endif
            }
        }
        .confirmationDialog("Discard the unsaved tag name?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Discard name", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Tag changes you already saved are kept.")
        }
        .confirmationDialog("Delete tag?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Delete tag", role: .destructive) {
                guard let pendingDeletion else { return }
                request(.remove(pendingDeletion.tag, expectedTransactionIDs: pendingDeletion.transactionIDs))
                self.pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let pendingDeletion {
                Text("“\(pendingDeletion.tag.name)” will be removed from all \(pendingDeletion.transactionIDs.count) tagged \(pendingDeletion.transactionIDs.count == 1 ? "transaction" : "transactions").")
            }
        }
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
        .confirmationDialog(DevelopmentProfileAcknowledgementPresentation.title, isPresented: Binding(
            get: { challenge != nil },
            set: { if !$0 { challenge = nil; pendingMutation = nil } }
        ), titleVisibility: .visible) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                guard let challenge else { return }
                let result = DevelopmentProfileAcknowledgementGate.shared.acknowledge(challenge)
                let action = pendingMutation
                self.challenge = nil
                pendingMutation = nil
                if result == .granted, let action { request(action) }
                else { message = "The active ledger changed. Reopen Tags before continuing." }
            }
            Button("Cancel", role: .cancel) { challenge = nil; pendingMutation = nil }
        } message: {
            Text(DevelopmentProfileAcknowledgementPresentation.message)
        }
#endif
    }

    @ViewBuilder
    private func tagRow(_ tag: TransactionTagDefinition, snapshot: TransactionTagSnapshot) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            if editingTag?.id == tag.id {
                Text("Rename tag").font(theme.typography.formCaption)
                    .foregroundStyle(theme.palette.secondaryText)
                HStack(spacing: theme.spacing.controlGap) {
                    TextField("Tag name", text: $editedName)
                        .lfTextField()
                        .focused($focusedField, equals: .rename)
                        .onSubmit(saveRename)
                        .accessibilityLabel("Tag name")
                    Button("Save", action: saveRename).lfPrimaryAction()
                        .disabled(!canEdit || editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") { editingTag = nil; editedName = "" }.lfSecondaryAction()
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.controlGap) {
                    Text(tag.name)
                        .font(theme.typography.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        editingTag = tag
                        editedName = tag.name
                        focusedField = .rename
                    } label: { Image(systemName: "pencil") }
                        .lfIconAction()
                        .accessibilityLabel("Rename \(tag.name)")
                        .help("Rename tag")
                    Button {
                        pendingDeletion = TransactionTagDeletion(tag: tag, transactionIDs: snapshot.transactionIDs(tagID: tag.id))
                    } label: { Image(systemName: "trash") }
                        .lfIconAction()
                        .accessibilityLabel("Delete \(tag.name)")
                        .help("Delete tag from all transactions")
                }
                if !transactionIDs.isEmpty {
                    membershipControls(tag, snapshot: snapshot)
                } else {
                    Text("\(snapshot.transactionIDs(tagID: tag.id).count) tagged transactions")
                        .font(theme.typography.formCaption)
                        .foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
        .disabled(!canEdit)
    }

    private func membershipControls(_ tag: TransactionTagDefinition, snapshot: TransactionTagSnapshot) -> some View {
        let attached = snapshot.transactionIDs(tagID: tag.id).intersection(transactionIDs)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: theme.spacing.controlGap) {
                membershipStatus(attachedCount: attached.count)
                Spacer(minLength: theme.spacing.controlGap)
                membershipButtons(tag, attached: attached)
            }
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                membershipStatus(attachedCount: attached.count)
                HStack(spacing: theme.spacing.controlGap) { membershipButtons(tag, attached: attached) }
            }
        }
    }

    private func membershipStatus(attachedCount: Int) -> some View {
        Text(attachedCount == transactionIDs.count
             ? "On all selected transactions"
             : "On \(attachedCount) of \(transactionIDs.count) selected transactions")
            .font(theme.typography.formCaption)
            .foregroundStyle(theme.palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func membershipButtons(_ tag: TransactionTagDefinition, attached: Set<String>) -> some View {
        Button("Add to selected") {
            request(.membership(tag, transactionIDs: transactionIDs, attached: true, expected: attached))
        }
        .lfSecondaryAction()
        .disabled(attached.count == transactionIDs.count)
        .accessibilityLabel("Add \(tag.name) to selected transactions")
        Button("Remove from selected") {
            request(.membership(tag, transactionIDs: transactionIDs, attached: false, expected: attached))
        }
        .lfSecondaryAction()
        .disabled(attached.isEmpty)
        .accessibilityLabel("Remove \(tag.name) from selected transactions")
    }

    private func create() {
        guard canEdit else { return }
        request(.save(.init(workspaceID: workspaceID, name: newName), replacing: nil))
    }

    private func saveRename() {
        guard canEdit, let expected = editingTag else { return }
        request(.save(.init(id: expected.id, workspaceID: expected.workspaceID, name: editedName), replacing: expected))
    }

    private func request(_ mutation: TransactionTagMutation) {
        guard canEdit, let generation else {
            message = TransactionTagError.refreshRequired.localizedDescription
            return
        }
        do {
            switch mutation {
            case .save(let tag, let expected):
                _ = try coordinator.saveTag(tag, replacing: expected, generation: generation)
            case .remove(let tag, let expected):
                _ = try coordinator.removeTag(tag, expectedTransactionIDs: expected, generation: generation)
            case .membership(let tag, let ids, let attached, let expected):
                _ = try coordinator.setMembership(tag: tag, transactionIDs: ids, isAttached: attached,
                    expectedAttachedTransactionIDs: expected, generation: generation)
            }
            finish(mutation)
            message = nil
        } catch {
#if DEBUG || LEDGERFORGE_DEVELOPER_TOOLS
            if case DevelopmentProfileAcknowledgementError.acknowledgementRequired(let challenge) = error {
                self.challenge = challenge
                pendingMutation = mutation
                return
            }
#endif
            if let tagError = error as? TransactionTagError {
                if tagError == .savedButRefreshFailed {
                    // This mutation already committed. Clear its input so
                    // retrying refresh cannot create a second new definition.
                    finish(mutation)
                    refreshRequired = true
                } else if tagError == .refreshRequired {
                    refreshRequired = true
                }
                message = tagError.localizedDescription
            } else if case RepositoryError.staleProviderGeneration = error {
                message = "The active ledger changed. Close Tags and reopen it from your current selection."
            } else {
                message = "The tag change could not be completed. Review the current tags and try again."
            }
        }
    }

    private func finish(_ mutation: TransactionTagMutation) {
        if case .save(_, let expected) = mutation {
            if expected == nil { newName = "" }
            else { editingTag = nil; editedName = "" }
        }
        updateDraftState()
    }

    private func retryRefresh() {
        guard let generation, generation == tagStore.generation else { return }
        do {
            try coordinator.retryRefresh(workspaceID: workspaceID, generation: generation)
            refreshRequired = false
            message = nil
        } catch {
            message = TransactionTagError.refreshRequired.localizedDescription
        }
    }

    private func updateDraftState() {
        draftOwner.isDirty = !newName.isEmpty || (editingTag != nil && editedName != editingTag?.name)
    }

    private func close() {
        if draftOwner.isDirty { confirmClose = true }
        else { dismiss() }
    }
}
