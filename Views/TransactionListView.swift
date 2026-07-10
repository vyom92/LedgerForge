//
//  TransactionListView.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import SwiftUI

struct TransactionListView: View {

    @StateObject private var viewModel = TransactionListViewModel()
    @State private var selectedTransactionID: Transaction.ID?

    private var filteredTransactions: [Transaction] { viewModel.filteredTransactions }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                transactionRangeAndSummary
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
    }

    private var transactionRangeAndSummary: some View {
        LFPanel {
            HStack(spacing: 14) {
                HStack(spacing: 0) {
                    rangeButton("All", selected: true)
                    rangeButton("Today", disabled: true)
                    rangeButton("Yesterday", disabled: true)
                    rangeButton("This Week", disabled: true)
                    rangeButton("This Month", disabled: true)
                    rangeButton("Last Month", disabled: true)
                    rangeButton("Custom", icon: "calendar", disabled: true)
                }

                Spacer()

                transactionSummaryCard("Total Inflow", value: format(viewModel.totalCredits), color: LFTheme.success)
                transactionSummaryCard("Total Outflow", value: format(viewModel.totalDebits), color: LFTheme.danger)
                transactionSummaryCard("Net Flow", value: format(viewModel.totalCredits - viewModel.totalDebits), color: LFTheme.success)
                transactionSummaryCard("Transactions", value: "\(viewModel.transactions.count)", color: LFTheme.info)
            }
        }
    }

    private var transactionFilterBar: some View {
        LFPanel {
            HStack(spacing: 12) {
                LFFilterChip(title: "Accounts", value: "Pending", width: 146, surface: LFTheme.backgroundDeep.opacity(0.65), showsChevron: false)
                LFFilterChip(title: "Categories", value: "Pending", width: 146, surface: LFTheme.backgroundDeep.opacity(0.65), showsChevron: false)
                LFFilterChip(title: "Types", value: "Pending", width: 146, surface: LFTheme.backgroundDeep.opacity(0.65), showsChevron: false)
                LFFilterChip(title: "Status", value: "Pending", width: 146, surface: LFTheme.backgroundDeep.opacity(0.65), showsChevron: false)

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
                    Image(systemName: "square")
                        .frame(width: 20)
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
                    Image(systemName: "ellipsis")
                        .frame(width: 18)
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
                    Text("Pagination pending")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(LFTheme.surfaceRaised.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(LFTheme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.top, 12)
            }
        }
    }

    private var transactionDetailPanel: some View {
        LFPanel {
            VStack(alignment: .leading, spacing: 16) {
                if let selected = selectedTransaction {
                    HStack(spacing: 12) {
                        Image(systemName: selected.credit != nil ? "arrow.down" : "arrow.up")
                            .foregroundStyle(selected.credit != nil ? LFTheme.success : LFTheme.danger)
                            .frame(width: 46, height: 46)
                            .background((selected.credit != nil ? LFTheme.success : LFTheme.danger).opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selected.description)
                                .font(.headline)
                                .lineLimit(2)
                            Text(formatSigned(selected))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(selected.credit != nil ? LFTheme.success : LFTheme.danger)
                                .monospacedDigit()
                        }
                        Spacer()
                        Image(systemName: "star")
                            .foregroundStyle(LFTheme.textSecondary)
                    }

                    LFStatusBadge(title: viewModel.validationPassed ? "Cleared" : "Needs Review", color: viewModel.validationPassed ? LFTheme.success : LFTheme.warning)

                    Divider().overlay(LFTheme.divider)

                    LFInfoRow(title: "Date", value: formatDate(selected.date), titleWidth: 86, verticalPadding: 0)
                    LFInfoRow(title: "Account", value: selected.account, titleWidth: 86, verticalPadding: 0)
                    LFInfoRow(title: "Category", value: "Imported", titleWidth: 86, verticalPadding: 0)
                    LFInfoRow(title: "Type", value: selected.credit != nil ? "Credit" : "Debit", titleWidth: 86, verticalPadding: 0)
                    LFInfoRow(title: "Description", value: selected.description, titleWidth: 86, verticalPadding: 0)
                    LFInfoRow(title: "Source", value: selected.sourceBank, titleWidth: 86, verticalPadding: 0)
                    LFInfoRow(title: "Balance After", value: selected.balance.map(format) ?? "—", titleWidth: 86, verticalPadding: 0)

                    Divider().overlay(LFTheme.divider)

                    Text("Validation")
                        .font(.headline)
                    Text(viewModel.validationPassed ? "Latest import validation passed." : "Latest import needs review or has not run.")
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
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
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? LFTheme.primaryHover : LFTheme.textSecondary)
                    .frame(width: 20)
                Text(formatDate(transaction.date))
                    .frame(width: 84, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.description)
                        .lineLimit(1)
                    Text(transaction.sourceBank)
                        .font(.caption2)
                        .foregroundStyle(LFTheme.textSecondary)
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
                LFStatusBadge(title: viewModel.validationPassed ? "Cleared" : "Review", color: viewModel.validationPassed ? LFTheme.success : LFTheme.warning)
                    .frame(width: 96, alignment: .leading)
                Text(transaction.balance.map(format) ?? "—")
                    .monospacedDigit()
                    .frame(width: 112, alignment: .trailing)
                Image(systemName: "ellipsis")
                    .foregroundStyle(LFTheme.textSecondary)
                    .frame(width: 18)
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

    private func rangeButton(_ title: String, selected: Bool = false, icon: String? = nil, disabled: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if let icon {
                Image(systemName: icon)
            }
        }
        .font(.caption)
        .foregroundStyle(disabled ? LFTheme.textSecondary.opacity(0.55) : LFTheme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(selected ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(Color.clear))
        .overlay(Rectangle().stroke(LFTheme.divider, lineWidth: 1))
        .opacity(disabled ? 0.65 : 1)
        .help(disabled ? "Date range filters are planned for a future sprint." : "")
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


    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    private func formatSigned(_ transaction: Transaction) -> String {
        let prefix = transaction.credit != nil ? "+" : "-"
        let magnitude = transaction.amount < .zero ? -transaction.amount : transaction.amount
        return "\(prefix)₹ \(format(magnitude))"
    }

    private func format(_ value: Decimal) -> String {
        Self.currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct TransactionListView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionListView()
    }
}
