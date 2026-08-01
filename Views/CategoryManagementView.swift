// LedgerForge
// CategoryManagementView.swift

import SwiftUI

private enum CategoryMutationIntent {
    case create(name: String)
    case rename(categoryID: String, name: String)
    case setArchived(categoryID: String, isArchived: Bool)
    case delete(categoryID: String)

#if DEBUG
    var protectedAction: DevelopmentProtectedAction {
        switch self {
        case .create: return .categoryCreate
        case .rename: return .categoryRename
        case .setArchived(_, let isArchived): return isArchived ? .categoryArchive : .categoryRestore
        case .delete: return .categoryDelete
        }
    }
#endif
}

struct CategoryManagementView: View {
    @ObservedObject private var categoryStore: CategoryStore
    private let coordinator: CategoryManaging
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif

    @State private var newName = ""
    @State private var editingCategoryID: String?
    @State private var editedName = ""
    @State private var categoryPendingDeletion: Category?
    @State private var message: String?
    @State private var categoryReconciliationRequired = false
#if DEBUG
    @State private var pendingMutation: CategoryMutationIntent?
    @State private var acknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
#endif

#if DEBUG
    @MainActor
    init(
        categoryStore: CategoryStore? = nil,
        coordinator: CategoryManaging? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self.categoryStore = resolvedStore
        self.coordinator = coordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
        self.acknowledgementGate = acknowledgementGate ?? .shared
    }
#else
    @MainActor
    init(
        categoryStore: CategoryStore? = nil,
        coordinator: CategoryManaging? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self.categoryStore = resolvedStore
        self.coordinator = coordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
    }
#endif

    var body: some View {
        LFPanel(title: "Category Management") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    TextField("New category name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(create)
                    Button("Create", action: create)
                        .buttonStyle(.borderedProminent)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if categoryStore.categories.isEmpty {
                    LFEmptyState(
                        title: "No categories yet",
                        message: "Create a category to classify imported transactions manually.",
                        systemImage: "tag"
                    )
                    .frame(minHeight: 150)
                } else {
                    categorySection(title: "Active", categories: categoryStore.activeCategories)
                    if !categoryStore.archivedCategories.isEmpty {
                        Divider().overlay(LFTheme.divider)
                        categorySection(title: "Archived", categories: categoryStore.archivedCategories)
                    }
                }

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(LFTheme.warning)
                }

                if categoryReconciliationRequired {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your category change was saved, but the app could not refresh. Further category changes are temporarily blocked until the repository is refreshed.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.warning)
                        Button("Retry refresh", action: retryCanonicalHydration)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete category?",
            isPresented: Binding(
                get: { categoryPendingDeletion != nil },
                set: { if !$0 { categoryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let category = categoryPendingDeletion else { return }
                request(.delete(categoryID: category.id))
                categoryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: {
            Text("Only unused categories can be deleted. Assigned transactions are never changed.")
        }
#if DEBUG
        .confirmationDialog(
            DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(
                get: { acknowledgementChallenge != nil && pendingMutation != nil },
                set: { if !$0 { cancelDevelopmentProfileAcknowledgement() } }
            ),
            titleVisibility: .visible
        ) {
            Button(DevelopmentProfileAcknowledgementPresentation.approvalLabel) {
                approveDevelopmentProfileAcknowledgement()
            }
            Button("Cancel", role: .cancel) {
                cancelDevelopmentProfileAcknowledgement()
            }
        } message: {
            Text(DevelopmentProfileAcknowledgementPresentation.message)
        }
#endif
    }

    @ViewBuilder
    private func categorySection(title: String, categories: [Category]) -> some View {
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LFTheme.textSecondary)

                ForEach(categories) { category in
                    categoryRow(category)
                    if category.id != categories.last?.id {
                        Divider().overlay(LFTheme.divider)
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 10) {
            Image(systemName: category.isArchived ? "archivebox" : "tag")
                .foregroundStyle(category.isArchived ? LFTheme.textSecondary : LFTheme.primaryHover)
                .frame(width: 22)

            if editingCategoryID == category.id {
                TextField("Category name", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveRename(category) }
                Button("Save") { saveRename(category) }
                    .buttonStyle(.bordered)
                Button("Cancel") { editingCategoryID = nil }
                    .buttonStyle(.plain)
            } else {
                Text(category.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isInUse(category) {
                    Text("Assigned")
                        .font(.caption2)
                        .foregroundStyle(LFTheme.textSecondary)
                }
                Button {
                    editingCategoryID = category.id
                    editedName = category.name
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Rename")

                Button {
                    request(.setArchived(
                        categoryID: category.id,
                        isArchived: !category.isArchived
                    ))
                } label: {
                    Image(systemName: category.isArchived ? "arrow.uturn.backward" : "archivebox")
                }
                .buttonStyle(.plain)
                .help(category.isArchived ? "Restore" : "Archive")

                Button {
                    categoryPendingDeletion = category
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(isInUse(category) ? LFTheme.textSecondary : LFTheme.danger)
                .disabled(isInUse(category))
                .help(isInUse(category) ? "Assigned categories cannot be deleted." : "Delete")
            }
        }
        .padding(.vertical, 5)
    }

    private func create() {
        request(.create(name: newName))
    }

    private func saveRename(_ category: Category) {
        request(.rename(categoryID: category.id, name: editedName))
    }

    private func isInUse(_ category: Category) -> Bool {
        categoryStore.snapshot.assignments.values.contains(category.id)
    }

    private func request(_ intent: CategoryMutationIntent) {
#if DEBUG
        switch acknowledgementGate.authorization(for: intent.protectedAction) {
        case .allowed:
            execute(intent)
        case .acknowledgementRequired(let challenge):
            pendingMutation = intent
            acknowledgementChallenge = challenge
        case .developmentDatabaseUnavailable:
            message = "The development database is unavailable."
        }
#else
        execute(intent)
#endif
    }

    private func execute(_ intent: CategoryMutationIntent) {
        do {
            switch intent {
            case .create(let name):
                _ = try coordinator.create(name: name)
                newName = ""
            case .rename(let categoryID, let name):
                _ = try coordinator.rename(categoryID: categoryID, name: name)
                editingCategoryID = nil
            case .setArchived(let categoryID, let isArchived):
                _ = try coordinator.setArchived(categoryID: categoryID, isArchived: isArchived)
            case .delete(let categoryID):
                try coordinator.deleteUnused(categoryID: categoryID)
            }
            message = nil
            categoryReconciliationRequired = false
        } catch {
#if DEBUG
            if let coordinatorError = error as? CategoryManagementCoordinatorError {
                switch coordinatorError {
                case .acknowledgementRequired(let challenge):
                    pendingMutation = intent
                    acknowledgementChallenge = challenge
                    return
                case .staleDevelopmentProfile:
                    pendingMutation = nil
                    acknowledgementChallenge = nil
                    message = "The active development database changed. Start the category action again."
                    return
                default:
                    break
                }
            }
#endif
            message = CategoryManagementPresentation.message(for: error)
            if let error = error as? CategoryManagementCoordinatorError {
                categoryReconciliationRequired = switch error {
                case .savedButRefreshFailed, .reconciliationRequired: true
                default: false
                }
            }
        }
    }

#if DEBUG
    private func approveDevelopmentProfileAcknowledgement() {
        guard let challenge = acknowledgementChallenge,
              let intent = pendingMutation else { return }
        switch acknowledgementGate.acknowledge(challenge) {
        case .granted, .noAcknowledgementRequired:
            pendingMutation = nil
            acknowledgementChallenge = nil
            execute(intent)
        case .staleGeneration, .developmentDatabaseUnavailable:
            pendingMutation = nil
            acknowledgementChallenge = nil
            message = "The active development database changed. Start the category action again."
        }
    }

    private func cancelDevelopmentProfileAcknowledgement() {
        pendingMutation = nil
        acknowledgementChallenge = nil
    }
#endif

    private func retryCanonicalHydration() {
        do {
            switch try coordinator.retryCanonicalHydration() {
            case .notRequired, .succeeded:
                categoryReconciliationRequired = false
                message = nil
            case .failed:
                categoryReconciliationRequired = true
                message = "The repository refresh is still unavailable. Category changes remain temporarily blocked."
            }
        } catch {
            categoryReconciliationRequired = true
            message = CategoryManagementPresentation.message(for: error)
        }
    }
}
