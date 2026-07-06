//
//  TransactionListView.swift
//  LedgerForge
//
//  Created by Vyom on 06/07/26.
//

import SwiftUI

struct TransactionListView: View {

    @StateObject private var viewModel = TransactionListViewModel()
    @State private var sortOrder = [KeyPathComparator(\Transaction.date)]
    @State private var selectedTransactionID: Transaction.ID?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private func format(_ value: Decimal?) -> String {
        guard let value else { return "" }
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? ""
    }

    private var totalDebits: Decimal { viewModel.totalDebits }
    private var totalCredits: Decimal { viewModel.totalCredits }
    private var closingBalance: Decimal? { viewModel.closingBalance }
    private var validationPassed: Bool { viewModel.validationPassed }
    private var filteredTransactions: [Transaction] { viewModel.filteredTransactions }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Transactions")
                .font(.title2)
                .bold()

            Text("\(viewModel.transactions.count) imported transaction(s)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {

                Label("Debits: \(format(totalDebits))", systemImage: "arrow.up.circle")
                    .foregroundStyle(.red)

                Label("Credits: \(format(totalCredits))", systemImage: "arrow.down.circle")
                    .foregroundStyle(.green)

                Spacer()

                if let closingBalance {
                    Text("Closing Balance: \(format(closingBalance))")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
            .font(.caption)

            Divider()

            GroupBox("Import Validation") {
                HStack {
                    Label(
                        validationPassed ? "Passed" : "Needs Review",
                        systemImage: validationPassed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(validationPassed ? .green : .orange)

                    Spacer()

                    Text("\(viewModel.transactions.count) transaction(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Search description...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
            HStack {
                Toggle("Credits", isOn: $viewModel.showOnlyCredits)
                Toggle("Debits", isOn: $viewModel.showOnlyDebits)
                Spacer()
            }
            .toggleStyle(.checkbox)

            Table(filteredTransactions) {

                TableColumn("Date") { transaction in
                    if let date = transaction.date {
                        Text(Self.dateFormatter.string(from: date))
                    } else {
                        Text("—")
                    }
                }

                TableColumn("Description") { transaction in
                    Text(transaction.description)
                        .lineLimit(1)
                        .help(transaction.description)
                }

                TableColumn("Debit") { transaction in
                    if let debit = transaction.debit {
                        Text(format(debit))
                            .foregroundStyle(.red)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("")
                    }
                }

                TableColumn("Credit") { transaction in
                    if let credit = transaction.credit {
                        Text(format(credit))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("")
                    }
                }

                TableColumn("Balance") { transaction in
                    if let balance = transaction.balance {
                        Text(format(balance))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        Text("")
                    }
                }
            }

            Divider()

            HStack {
                Text("Showing \(filteredTransactions.count) of \(viewModel.transactions.count) transaction(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let selectedTransactionID {
                    Text("Selected: \(selectedTransactionID.uuidString.prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
        }
        .padding()
    }
}

#Preview {
    TransactionListView()
}
