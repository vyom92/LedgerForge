//
// LedgerForge
// ContentView.swift
// Version: 0.0.8
//

import SwiftUI
import UniformTypeIdentifiers

private enum AppShellSection: String {
    case dashboard = "Dashboard"
    case accounts = "Accounts"
    case transactions = "Transactions"
    case imports = "Imports"
    case insights = "Insights"
    case budgets = "Budgets"
    case reports = "Reports"
    case settings = "Settings"
    case developer = "Developer"

    var systemImage: String {
        switch self {
        case .dashboard:
            return "house"
        case .accounts:
            return "building.columns"
        case .transactions:
            return "list.bullet.rectangle"
        case .imports:
            return "tray.and.arrow.down"
        case .insights:
            return "chart.bar"
        case .budgets:
            return "target"
        case .reports:
            return "doc.text"
        case .settings:
            return "gearshape"
        case .developer:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ContentView: View {

    @State private var showingImporter = false
    @State private var selectedFile = "No statement imported"
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var selectedSection: AppShellSection = .dashboard
    @State private var didStartRepositoryHydration = false
    @State private var developerModeEnabled = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                toolbar

                Divider()

                content
            }
            .frame(minWidth: 760, maxWidth: .infinity, maxHeight: .infinity)
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
                selectedSection = .transactions

            case .failure(let error):
                selectedFile = error.localizedDescription
                selectedSection = .imports
            }
        }
        .task {
            hydrateDashboardOnce()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                        .frame(width: 38, height: 38)
                        .overlay {
                            Text("LF")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("LedgerForge")
                            .font(.headline)
                        Text("Personal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 18)

                sidebarButton(.dashboard)
                sidebarButton(.accounts)
                sidebarButton(.transactions)
                sidebarButton(.imports)

                Divider()
                    .padding(.vertical, 14)

                sidebarButton(.insights, badge: "Soon")
                sidebarButton(.budgets, badge: "Soon")
                sidebarButton(.reports, badge: "Soon")

                Divider()
                    .padding(.vertical, 14)

                sidebarButton(.settings)

                if developerModeEnabled {
                    sidebarButton(.developer)
                }
            }
            .padding(20)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Last import")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedFile)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Label(dashboardViewModel.presentationState.message, systemImage: dashboardStatusIcon)
                    .font(.caption2)
                    .foregroundStyle(dashboardStatusColor)
                    .lineLimit(2)
            }
            .padding(20)
        }
        .frame(minWidth: 240, idealWidth: 260, maxWidth: 300, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedSection.rawValue)
                    .font(.title2.weight(.semibold))
                Text(toolbarSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                // Placeholder only; date range behavior belongs to a later dashboard sprint.
            } label: {
                Label("1 Apr - 8 Jul 2026", systemImage: "calendar")
            }
            .disabled(true)

            Button {
                // Placeholder only; filters are outside Sprint 21 shell scope.
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .disabled(true)

            Button {
                showingImporter = true
            } label: {
                Label("Import Statement", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .dashboard:
            dashboardContent
        case .accounts:
            accountsContent
        case .transactions:
            TransactionListView()
        case .imports:
            importsContent
        case .insights:
            placeholderContent(
                title: "Insights",
                message: "Insights are planned for a future sprint."
            )
        case .budgets:
            placeholderContent(
                title: "Budgets",
                message: "Budgets are planned for a future sprint."
            )
        case .reports:
            placeholderContent(
                title: "Reports",
                message: "Reports are planned for a future sprint."
            )
        case .settings:
            settingsContent
        case .developer:
            DeveloperConsoleView()
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Here's your financial overview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    dashboardMetricCard("Net Worth", value: dashboardViewModel.snapshot.netWorth)
                    dashboardMetricCard("Income", value: dashboardViewModel.snapshot.income, tint: .green)
                    dashboardMetricCard("Expenses", value: dashboardViewModel.snapshot.expenses, tint: .red)
                    dashboardMetricCard("Cash Flow", value: dashboardViewModel.snapshot.cashFlow, tint: dashboardViewModel.snapshot.cashFlow >= .zero ? .green : .red)
                }

                HStack(alignment: .top, spacing: 14) {
                    accountsCard
                        .frame(maxWidth: .infinity)

                    importActivityCard
                        .frame(width: 320)
                }

                HStack(alignment: .top, spacing: 14) {
                    recentTransactionsCard
                        .frame(maxWidth: .infinity)

                    quickActionsCard
                        .frame(width: 320)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accountsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if dashboardViewModel.accountSummaries.isEmpty {
                    placeholderContent(
                        title: "No Accounts",
                        message: "Repository-backed accounts will appear here after a trusted import."
                    )
                } else {
                    ForEach(dashboardViewModel.accountSummaries) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.displayName)
                                    .font(.headline)
                                Text(account.institution)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(account.currencyCode) \(account.currentBalance, format: .number)")
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var importsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Import Activity") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedFile)
                        .font(.headline)

                    Text(selectedFile == "No statement imported" ? "No recent imports" : "Last import completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Statement", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Text("Document Preview is reserved for the import workflow and is intentionally not part of primary navigation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Application") {
                Toggle(
                    "Developer Mode",
                    isOn: Binding(
                        get: { developerModeEnabled },
                        set: { newValue in
                            developerModeEnabled = newValue
                            if !newValue && selectedSection == .developer {
                                selectedSection = .settings
                            }
                        }
                    )
                )
                .toggleStyle(.checkbox)
                .padding(.vertical, 4)
            }

            Text("Settings are intentionally minimal in the Sprint 21 shell.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var accountsCard: some View {
        GroupBox("Accounts") {
            VStack(alignment: .leading, spacing: 10) {
                if dashboardViewModel.accountSummaries.isEmpty {
                    Text("No repository-backed accounts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dashboardViewModel.accountSummaries) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(account.institution)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(account.currencyCode) \(account.currentBalance, format: .number)")
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var recentTransactionsCard: some View {
        GroupBox("Recent Transactions") {
            VStack(alignment: .leading, spacing: 10) {
                if dashboardViewModel.recentTransactionSummaries.isEmpty {
                    Text("No repository-backed transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dashboardViewModel.recentTransactionSummaries) { transaction in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.description)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(transaction.currency)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(transaction.amount, format: .number)")
                                .foregroundStyle(transaction.isCredit ? .green : .red)
                                .monospacedDigit()
                        }
                    }
                }

                Divider()

                Button {
                    selectedSection = .transactions
                } label: {
                    Label("View All Transactions", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .padding(.vertical, 4)
        }
    }

    private var importActivityCard: some View {
        GroupBox("Import Activity") {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedFile)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(selectedFile == "No statement imported" ? "No recent imports" : "Last import completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Label(dashboardViewModel.presentationState.message, systemImage: dashboardStatusIcon)
                    .font(.caption)
                    .foregroundStyle(dashboardStatusColor)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var quickActionsCard: some View {
        GroupBox("Quick Actions") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import Statement", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)

                Button {
                    selectedSection = .transactions
                } label: {
                    Label("View All Transactions", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sidebarButton(_ section: AppShellSection, badge: String? = nil) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Label(section.rawValue, systemImage: section.systemImage)
                    .labelStyle(.titleAndIcon)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedSection == section ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func dashboardMetricCard(
        _ title: String,
        value: Decimal,
        tint: Color = .blue
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("₹ \(value, format: .number)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Rectangle()
                .fill(tint)
                .frame(height: 2)
                .clipShape(Capsule())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func placeholderContent(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var toolbarSubtitle: String {
        switch selectedSection {
        case .dashboard:
            return "Financial overview"
        case .accounts:
            return "Repository-backed accounts"
        case .transactions:
            return "Trusted runtime-store transactions"
        case .imports:
            return "Import activity and entry point"
        case .insights, .budgets, .reports:
            return "Planned future module"
        case .settings:
            return "Application preferences"
        case .developer:
            return "Diagnostics"
        }
    }

    private func hydrateDashboardOnce() {
        guard !didStartRepositoryHydration else { return }
        didStartRepositoryHydration = true
        dashboardViewModel.markHydrationStarted()

        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded()
            dashboardViewModel.markHydrationCompleted(result)
        } catch {
            dashboardViewModel.markHydrationFailed(error)
            DeveloperConsole.shared.log("Dashboard Hydration: FAILED")
            DeveloperConsole.shared.log(error.localizedDescription)
        }
    }

    private var dashboardStatusIcon: String {
        switch dashboardViewModel.presentationState {
        case .loading:
            return "hourglass"
        case .empty:
            return "tray"
        case .loaded:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var dashboardStatusColor: Color {
        switch dashboardViewModel.presentationState {
        case .loading, .empty:
            return .secondary
        case .loaded:
            return .green
        case .failed:
            return .orange
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
