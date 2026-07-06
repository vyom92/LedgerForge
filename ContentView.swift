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
    @ObservedObject private var documentStore = DocumentStore.shared
    @State private var selectedTab = 0

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
                            Text("₹ --")
                                .font(.headline.weight(.semibold))
                        }
                        Divider()
                        HStack {
                            Text("Income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ --")
                                .font(.headline.weight(.semibold))
                        }
                        Divider()
                        HStack {
                            Text("Expenses")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ --")
                                .font(.headline.weight(.semibold))
                        }
                        Divider()
                        HStack {
                            Text("Cash Flow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("₹ --")
                                .font(.headline.weight(.semibold))
                        }
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

                TransactionListView(
                    transactions: documentStore.transactions
                )
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

    }
}

#Preview {
    ContentView()
}
