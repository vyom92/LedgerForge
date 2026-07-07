//
// LedgerForge
// ContentView.swift
// Version: 0.0.7
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var showingImporter = false
    @State private var selectedFile = "No statement imported"
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var selectedTab = 0
    @State private var didStartRepositoryHydration = false
    @State private var repositoryHydrationMessage = "Loading persisted dashboard..."

    var body: some View {

        HStack(spacing: 0) {

            // MARK: Left Panel

            VStack(alignment: .leading, spacing: 18) {

                Text("LedgerForge")
                    .font(.largeTitle)
                    .bold()

                Text("Personal Accounting & Reconciliation")
                    .foregroundStyle(.secondary)

                GroupBox("Financial Snapshot") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Net Worth")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ \(dashboardViewModel.snapshot.netWorth, format: .number)")
                                .font(.headline.weight(.semibold))
                        }
                        Divider()
                        HStack {
                            Text("Income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ \(dashboardViewModel.snapshot.income, format: .number)")
                                .font(.headline.weight(.semibold))
                        }
                        Divider()
                        HStack {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ \(dashboardViewModel.snapshot.expenses, format: .number)")
                                .font(.headline.weight(.semibold))
                        }
                        Divider()
                        HStack {
                            Text("Cash Flow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ \(dashboardViewModel.snapshot.cashFlow, format: .number)")
                                .font(.headline.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Accounts") {
                    VStack(alignment: .leading, spacing: 8) {
                        if dashboardViewModel.accounts.isEmpty {
                            Text("No repository-backed accounts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dashboardViewModel.accounts.prefix(3)) { account in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.nickname ?? account.name)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                        Text(account.institution)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(account.currencyCode) \(account.currentBalance, format: .number)")
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            }
                        }

                        Divider()

                        Text(repositoryHydrationMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent Import")
                        .font(.headline)

                    Text(selectedFile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if selectedFile == "No statement imported" {
                        Text("No recent imports")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Last import completed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Import Statement") {
                    showingImporter = true
                }
                .buttonStyle(.borderedProminent)
                
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Coming Soon")
                        .font(.headline)

                    Label("Accounts", systemImage: "building.columns")
                        .foregroundStyle(.secondary)

                    Label("Budgets", systemImage: "chart.pie")
                        .foregroundStyle(.secondary)

                    Label("Insights", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

            }
            .padding(30)
            .frame(minWidth: 300, idealWidth: 320)

            Divider()

            // MARK: Middle Panel

            TabView(selection: $selectedTab) {

                DocumentPreviewView()
                    .tabItem {
                        Label("Preview", systemImage: "doc.text")
                    }
                    .tag(0)

                TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

                DeveloperConsoleView()
                    .tabItem {
                        Label("Console", systemImage: "terminal")
                    }
                    .tag(2)
            }
            .frame(minWidth: 700)

        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [
                .commaSeparatedText,
                .spreadsheet
            ]
        ) { result in

            switch result {

            case .success(let url):

                selectedFile = url.lastPathComponent
                ImportEngine.shared.importFile(from: url)
                selectedTab = 1

            case .failure(let error):

                selectedFile = error.localizedDescription

            }

        }
        .task {
            hydrateDashboardOnce()
        }

    }

    private func hydrateDashboardOnce() {
        guard !didStartRepositoryHydration else { return }
        didStartRepositoryHydration = true

        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded()
            if result.accountCount == 0 && result.transactionCount == 0 {
                repositoryHydrationMessage = "No persisted dashboard data"
            } else {
                repositoryHydrationMessage = "Loaded \(result.accountCount) account(s), \(result.transactionCount) transaction(s)"
            }
        } catch {
            repositoryHydrationMessage = "Dashboard load failed"
            DeveloperConsole.shared.log("Dashboard Hydration: FAILED")
            DeveloperConsole.shared.log(error.localizedDescription)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
