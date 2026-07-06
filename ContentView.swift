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

            VStack(spacing: 25) {

                Text("LedgerForge")
                    .font(.largeTitle)
                    .bold()

                Text("Personal Accounting & Reconciliation")
                    .foregroundStyle(.secondary)

                Button("Import Statement") {
                    showingImporter = true
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text(selectedFile)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

            }
            .padding(30)
            .frame(minWidth: 260)

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
