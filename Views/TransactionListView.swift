//
//  TransactionListView.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import SwiftUI

private struct TransactionCategoryMutationIntent {
    let categoryID: String?
    let transactionID: String

#if DEBUG
    var protectedAction: DevelopmentProtectedAction {
        categoryID == nil ? .transactionCategoryClear : .transactionCategoryAssignment
    }
#endif
}

struct TransactionListView: View {

    @StateObject private var viewModel = TransactionListViewModel()
    @ObservedObject private var categoryStore: CategoryStore
    private let categoryCoordinator: CategoryManaging
#if DEBUG
    private let acknowledgementGate: DevelopmentProfileAcknowledgementGate
#endif
    @State private var selectedTransactionID: Transaction.ID?
    @State private var categoryMessage: String?
    @State private var categoryReconciliationRequired = false
#if DEBUG
    @State private var pendingCategoryMutation: TransactionCategoryMutationIntent?
    @State private var acknowledgementChallenge: DevelopmentProfileAcknowledgementChallenge?
#endif

    private var filteredTransactions: [Transaction] { viewModel.filteredTransactions }

#if DEBUG
    @MainActor
    init(
        categoryStore: CategoryStore? = nil,
        categoryCoordinator: CategoryManaging? = nil,
        acknowledgementGate: DevelopmentProfileAcknowledgementGate? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self.categoryStore = resolvedStore
        self.categoryCoordinator = categoryCoordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
        self.acknowledgementGate = acknowledgementGate ?? .shared
    }
#else
    @MainActor
    init(
        categoryStore: CategoryStore? = nil,
        categoryCoordinator: CategoryManaging? = nil
    ) {
        let resolvedStore = categoryStore ?? .shared
        self.categoryStore = resolvedStore
        self.categoryCoordinator = categoryCoordinator ?? CategoryManagementCoordinator(categoryStore: resolvedStore)
    }
#endif

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                transactionSummary
                transactionFilterBar
                transactionTable
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            transactionDetailPanel
                .frame(width: 330)
        }
        .padding(28)
        .background(LFTheme.backgroundGradient)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
#if DEBUG
        .confirmationDialog(
            DevelopmentProfileAcknowledgementPresentation.title,
            isPresented: Binding(
                get: { acknowledgementChallenge != nil && pendingCategoryMutation != nil },
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

    private var transactionSummary: some View {
        LFPanel {
            HStack(spacing: 14) {
                ForEach(viewModel.currencySummaries) { summary in
                    transactionSummaryCard("\(summary.currency.code) Inflow", value: MoneyFormatting.display(summary.inflow), color: LFTheme.success)
                    transactionSummaryCard("\(summary.currency.code) Outflow", value: MoneyFormatting.display(summary.outflow), color: LFTheme.danger)
                    transactionSummaryCard("\(summary.currency.code) Net", value: MoneyFormatting.display(summary.net), color: LFTheme.success)
                }
                transactionSummaryCard("Transactions", value: "\(viewModel.transactions.count)", color: LFTheme.info)
            }
        }
    }

    private var transactionFilterBar: some View {
        LFPanel {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LFTheme.textSecondary)
                    TextField("Search within results...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(LFTheme.backgroundDeep.opacity(0.65))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(LFTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                transactionTypeButton(
                    "Credits",
                    systemImage: "arrow.down.circle",
                    selected: viewModel.showOnlyCredits,
                    color: LFTheme.success
                ) {
                    if viewModel.showOnlyCredits {
                        viewModel.showOnlyCredits = false
                    } else {
                        viewModel.showOnlyCredits = true
                        viewModel.showOnlyDebits = false
                    }
                }

                transactionTypeButton(
                    "Debits",
                    systemImage: "arrow.up.circle",
                    selected: viewModel.showOnlyDebits,
                    color: LFTheme.danger
                ) {
                    if viewModel.showOnlyDebits {
                        viewModel.showOnlyDebits = false
                    } else {
                        viewModel.showOnlyDebits = true
                        viewModel.showOnlyCredits = false
                    }
                }
            }
            .font(.caption)
        }
    }

    private var transactionTable: some View {
        LFPanel {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Date")
                        .frame(width: 84, alignment: .leading)
                    Text("Description")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Account")
                        .frame(width: 130, alignment: .leading)
                    Text("Type")
                        .frame(width: 72, alignment: .leading)
                    Text("Amount")
                        .frame(width: 120, alignment: .trailing)
                    Text("Status")
                        .frame(width: 96, alignment: .leading)
                    Text("Balance")
                        .frame(width: 112, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.vertical, 10)

                if filteredTransactions.isEmpty {
                    LFEmptyState(
                        title: "No transactions found",
                        message: "Try changing search text or clearing the credit/debit toggles.",
                        systemImage: "tray"
                    )
                    .frame(minHeight: 260)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTransactions) { transaction in
                                transactionRow(transaction)
                                Divider().overlay(LFTheme.divider)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }

                HStack {
                    Text("Showing \(filteredTransactions.count) of \(viewModel.transactions.count) transactions")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.top, 12)
            }
        }
    }

    private var transactionDetailPanel: some View {
        LFPanel {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let selected = selectedTransaction {
                        let presentation = viewModel.detailPresentation(for: selected)
                        HStack(spacing: 12) {
                            Image(systemName: presentation.direction == "Credit" ? "arrow.down" : "arrow.up")
                                .foregroundStyle(presentation.direction == "Credit" ? LFTheme.success : LFTheme.danger)
                                .frame(width: 46, height: 46)
                                .background((presentation.direction == "Credit" ? LFTheme.success : LFTheme.danger).opacity(0.13))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(presentation.description)
                                    .font(.headline)
                                    .lineLimit(2)
                                Text(presentation.signedAmount)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(presentation.direction == "Credit" ? LFTheme.success : LFTheme.danger)
                                    .monospacedDigit()
                            }
                            Spacer()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(presentation.accessibilityText)

                        detailSection("Transaction") {
                            LFInfoRow(title: "Direction", value: presentation.direction, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: presentation.statementDateRole, value: presentation.statementDate, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Description", value: presentation.description, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Native currency", value: presentation.nativeCurrency, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Balance After", value: presentation.runningBalance, titleWidth: 100, verticalPadding: 0)
                        }

                        detailSection("Account and category") {
                            LFInfoRow(title: "Account", value: presentation.accountDisplayName, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Institution", value: presentation.institution, titleWidth: 100, verticalPadding: 0)
                            categoryPicker(for: selected, titleWidth: 100)
                        }

                        detailSection("Import provenance") {
                            LFInfoRow(title: "Availability", value: presentation.provenanceAvailability.title, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Source document", value: presentation.sourceDocumentName, titleWidth: 100, verticalPadding: 0)
                            LFInfoRow(title: "Imported", value: presentation.importedAtText, titleWidth: 100, verticalPadding: 0)
                        }

                        detailSection("Validation") {
                            if let validation = presentation.validation {
                                LFStatusBadge(
                                    title: validation.title,
                                    color: validation.isPassed ? LFTheme.success : LFTheme.warning
                                )
                                Text(validation.detail)
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                            } else {
                                LFInfoRow(title: "Outcome", value: "Unavailable", titleWidth: 100, verticalPadding: 0)
                                Text("Validation is unavailable for this imported transaction.")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                            }
                        }

                        if let categoryMessage {
                            Text(categoryMessage)
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
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "cursorarrow.click")
                                .font(.system(size: 34))
                                .foregroundStyle(LFTheme.primaryHover)
                            Text("Select a transaction")
                                .font(.headline)
                            Text("Details appear here without leaving the transaction table.")
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 260)
                    }
                }
            }
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LFTheme.surfaceRaised.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LFTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var selectedTransaction: Transaction? {
        guard let selectedTransactionID else {
            return filteredTransactions.first
        }
        return filteredTransactions.first { $0.id == selectedTransactionID }
    }

    private func transactionRow(_ transaction: Transaction) -> some View {
        let isSelected = selectedTransaction?.id == transaction.id
        return Button {
            selectedTransactionID = transaction.id
        } label: {
            HStack(spacing: 12) {
                Text(formatDate(transaction.statementDate))
                    .frame(width: 84, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.description)
                        .lineLimit(1)
                    Text(transaction.sourceBank)
                        .font(.caption2)
                        .foregroundStyle(LFTheme.textSecondary)
                        .lineLimit(1)
                    Text(categoryName(for: transaction))
                        .font(.caption2)
                        .foregroundStyle(LFTheme.primaryHover)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(transaction.account)
                    .lineLimit(1)
                    .frame(width: 130, alignment: .leading)
                Image(systemName: transaction.credit != nil ? "arrow.down" : "arrow.up")
                    .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                    .frame(width: 72, alignment: .leading)
                Text(formatSigned(transaction))
                    .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                    .monospacedDigit()
                    .frame(width: 120, alignment: .trailing)
                if let validation = viewModel.validationPresentation(for: transaction) {
                    LFStatusBadge(
                        title: validation.title,
                        color: validation.isPassed ? LFTheme.success : LFTheme.warning
                    )
                    .frame(width: 96, alignment: .leading)
                } else {
                    Color.clear.frame(width: 96, height: 1)
                }
                Text(transaction.runningBalanceMoney.map { MoneyFormatting.display($0) } ?? "—")
                    .monospacedDigit()
                    .frame(width: 112, alignment: .trailing)
            }
            .font(.caption)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? LFTheme.primary.opacity(0.16) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isSelected ? LFTheme.primary : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func categoryPicker(for transaction: Transaction, titleWidth: CGFloat = 86) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Category")
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: titleWidth, alignment: .leading)
            Picker(
                "Category",
                selection: Binding<String?>(
                    get: {
                        guard let transactionID = transaction.repositoryTransactionId else { return nil }
                        return categoryStore.snapshot.assignments[transactionID]
                    },
                    set: { assign($0, to: transaction) }
                )
            ) {
                Text("Uncategorized").tag(String?.none)
                ForEach(assignableCategories(for: transaction)) { category in
                    Text(category.isArchived ? "\(category.name) (Archived)" : category.name)
                        .tag(Optional(category.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(transaction.repositoryTransactionId == nil)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption)
    }

    private func categoryName(for transaction: Transaction) -> String {
        guard let transactionID = transaction.repositoryTransactionId else { return "Uncategorized" }
        return categoryStore.category(forTransactionID: transactionID)?.name ?? "Uncategorized"
    }

    private func assignableCategories(for transaction: Transaction) -> [Category] {
        guard let transactionID = transaction.repositoryTransactionId,
              let assigned = categoryStore.category(forTransactionID: transactionID),
              assigned.isArchived else {
            return categoryStore.activeCategories
        }
        return (categoryStore.activeCategories + [assigned]).sorted {
            if $0.normalizedName != $1.normalizedName { return $0.normalizedName < $1.normalizedName }
            return $0.id < $1.id
        }
    }

    private func assign(_ categoryID: String?, to transaction: Transaction) {
        guard let transactionID = transaction.repositoryTransactionId else {
            categoryMessage = "Only persisted imported transactions can be classified."
            return
        }
        requestCategoryMutation(
            TransactionCategoryMutationIntent(
                categoryID: categoryID,
                transactionID: transactionID
            )
        )
    }

    private func requestCategoryMutation(_ intent: TransactionCategoryMutationIntent) {
#if DEBUG
        switch acknowledgementGate.authorization(for: intent.protectedAction) {
        case .allowed:
            executeCategoryMutation(intent)
        case .acknowledgementRequired(let challenge):
            pendingCategoryMutation = intent
            acknowledgementChallenge = challenge
        case .developmentDatabaseUnavailable:
            categoryMessage = "The development database is unavailable."
        }
#else
        executeCategoryMutation(intent)
#endif
    }

    private func executeCategoryMutation(_ intent: TransactionCategoryMutationIntent) {
        do {
            _ = try categoryCoordinator.setCategory(
                categoryID: intent.categoryID,
                transactionID: intent.transactionID
            )
            categoryMessage = nil
            categoryReconciliationRequired = false
        } catch {
#if DEBUG
            if let coordinatorError = error as? CategoryManagementCoordinatorError {
                switch coordinatorError {
                case .acknowledgementRequired(let challenge):
                    pendingCategoryMutation = intent
                    acknowledgementChallenge = challenge
                    return
                case .staleDevelopmentProfile:
                    pendingCategoryMutation = nil
                    acknowledgementChallenge = nil
                    categoryMessage = "The active development database changed. Start the category change again."
                    return
                default:
                    break
                }
            }
#endif
            categoryMessage = CategoryManagementPresentation.message(for: error)
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
              let intent = pendingCategoryMutation else { return }
        switch acknowledgementGate.acknowledge(challenge) {
        case .granted, .noAcknowledgementRequired:
            pendingCategoryMutation = nil
            acknowledgementChallenge = nil
            executeCategoryMutation(intent)
        case .staleGeneration, .developmentDatabaseUnavailable:
            pendingCategoryMutation = nil
            acknowledgementChallenge = nil
            categoryMessage = "The active development database changed. Start the category change again."
        }
    }

    private func cancelDevelopmentProfileAcknowledgement() {
        pendingCategoryMutation = nil
        acknowledgementChallenge = nil
    }
#endif

    private func retryCanonicalHydration() {
        do {
            switch try categoryCoordinator.retryCanonicalHydration() {
            case .notRequired, .succeeded:
                categoryReconciliationRequired = false
                categoryMessage = nil
            case .failed:
                categoryReconciliationRequired = true
                categoryMessage = "The repository refresh is still unavailable. Category changes remain temporarily blocked."
            }
        } catch {
            categoryReconciliationRequired = true
            categoryMessage = CategoryManagementPresentation.message(for: error)
        }
    }

    private func transactionTypeButton(
        _ title: String,
        systemImage: String,
        selected: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minWidth: 92)
                .background(selected ? color.opacity(0.16) : LFTheme.backgroundDeep.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(selected ? color.opacity(0.65) : LFTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? color : LFTheme.text)
    }

    private func transactionSummaryCard(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(12)
        .frame(width: 136, alignment: .leading)
        .background(LFTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }


    private func formatDate(_ date: StatementDate?) -> String { date?.presentation ?? "—" }

    private func formatSigned(_ transaction: Transaction) -> String {
        MoneyFormatting.signedDisplay(transaction.money, isCredit: transaction.creditMoney != nil)
    }

}

struct TransactionListView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionListView()
    }
}
