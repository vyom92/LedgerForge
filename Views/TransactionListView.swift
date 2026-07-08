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
            .frame(maxWidth: .infinity)

            transactionDetailPanel
                .frame(width: 330)
        }
        .padding(28)
        .background(LFTheme.backgroundGradient)
    }

    private var transactionRangeAndSummary: some View {
        LFPanel {
            HStack(spacing: 14) {
                HStack(spacing: 0) {
                    rangeButton("All", selected: true)
                    rangeButton("Today")
                    rangeButton("Yesterday")
                    rangeButton("This Week")
                    rangeButton("This Month", selected: true)
                    rangeButton("Last Month")
                    rangeButton("Custom", icon: "calendar")
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
                filterMenu("All Accounts")
                filterMenu("All Categories")
                filterMenu("All Types")
                filterMenu("All Status")

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

                Button {
                    if viewModel.showOnlyCredits {
                        viewModel.showOnlyCredits = false
                    } else {
                        viewModel.showOnlyCredits = true
                        viewModel.showOnlyDebits = false
                    }
                } label: {
                    Label("Credits", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.showOnlyCredits ? LFTheme.success : LFTheme.text)

                Button {
                    if viewModel.showOnlyDebits {
                        viewModel.showOnlyDebits = false
                    } else {
                        viewModel.showOnlyDebits = true
                        viewModel.showOnlyCredits = false
                    }
                } label: {
                    Label("Debits", systemImage: "arrow.up.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.showOnlyDebits ? LFTheme.danger : LFTheme.text)
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
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundStyle(LFTheme.primaryHover)
                        Text("No transactions found")
                            .font(.headline)
                        Text("Try changing search text or clearing the credit/debit toggles.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(filteredTransactions) { transaction in
                        transactionRow(transaction)
                        Divider().overlay(LFTheme.divider)
                    }
                }

                HStack {
                    Text("Showing \(filteredTransactions.count) of \(viewModel.transactions.count) transactions")
                    Spacer()
                    paginationButton("chevron.left")
                    Text("1")
                        .font(.caption.weight(.semibold))
                        .frame(width: 30, height: 30)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    paginationButton("2")
                    paginationButton("3")
                    paginationButton("chevron.right")
                    Text("10 / page")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(LFTheme.surfaceRaised)
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

                    statusBadge(viewModel.validationPassed ? "Cleared" : "Needs Review", color: viewModel.validationPassed ? LFTheme.success : LFTheme.warning)

                    Divider().overlay(LFTheme.divider)

                    detailRow("Date", value: formatDate(selected.date))
                    detailRow("Account", value: selected.account)
                    detailRow("Category", value: "Imported")
                    detailRow("Type", value: selected.credit != nil ? "Credit" : "Debit")
                    detailRow("Description", value: selected.description)
                    detailRow("Source", value: selected.sourceBank)
                    detailRow("Balance After", value: selected.balance.map(format) ?? "—")

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
        Button {
            selectedTransactionID = transaction.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedTransactionID == transaction.id ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selectedTransactionID == transaction.id ? LFTheme.primaryHover : LFTheme.textSecondary)
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
                statusBadge(viewModel.validationPassed ? "Cleared" : "Review", color: viewModel.validationPassed ? LFTheme.success : LFTheme.warning)
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
            .background(selectedTransactionID == transaction.id ? LFTheme.primary.opacity(0.16) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(selectedTransactionID == transaction.id ? LFTheme.primary : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    private func rangeButton(_ title: String, selected: Bool = false, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if let icon {
                Image(systemName: icon)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(selected ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(Color.clear))
        .overlay(Rectangle().stroke(LFTheme.divider, lineWidth: 1))
    }

    private func filterMenu(_ title: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 146)
        .background(LFTheme.backgroundDeep.opacity(0.65))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(LFTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
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

    private func paginationButton(_ titleOrIcon: String) -> some View {
        let isIcon = titleOrIcon.contains("chevron")
        return Group {
            if isIcon {
                Image(systemName: titleOrIcon)
            } else {
                Text(titleOrIcon)
            }
        }
        .font(.caption)
        .frame(width: 30, height: 30)
        .background(LFTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func statusBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 86, alignment: .leading)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
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
