//
// LedgerForge
// ContentView.swift
// Version: 0.0.9
//

import SwiftUI
import UniformTypeIdentifiers

private enum AppShellSection: String, CaseIterable {
    case dashboard = "Dashboard"
    case accounts = "Accounts"
    case transactions = "Transactions"
    case imports = "Import"
    case insights = "Insights"
    case budgets = "Budgets"
    case reports = "Reports"
    case investments = "Investments"
    case timeline = "Financial Timeline"
    case intelligence = "Financial Intelligence"
    case automation = "Rules & Automation"
    case settings = "Settings"
    case developer = "Developer Console"

    var systemImage: String {
        switch self {
        case .dashboard:
            return "house"
        case .accounts:
            return "wallet.pass"
        case .transactions:
            return "arrow.left.arrow.right.square"
        case .imports:
            return "square.and.arrow.down"
        case .insights:
            return "chart.xyaxis.line"
        case .budgets:
            return "shield"
        case .reports:
            return "doc.text"
        case .investments:
            return "arrow.up.right"
        case .timeline:
            return "scope"
        case .intelligence:
            return "cube.transparent"
        case .automation:
            return "wand.and.stars"
        case .settings:
            return "gearshape"
        case .developer:
            return "arrow.up.left.and.arrow.down.right"
        }
    }

    var isFutureModule: Bool {
        switch self {
        case .insights, .budgets, .reports, .investments, .timeline, .intelligence, .automation:
            return true
        default:
            return false
        }
    }
}

enum LFTheme {
    static let background = Color(hex: 0x0B0F19)
    static let backgroundDeep = Color(hex: 0x07101E)
    static let surface = Color(hex: 0x111827).opacity(0.78)
    static let surfaceRaised = Color(hex: 0x1A2233).opacity(0.72)
    static let border = Color.white.opacity(0.11)
    static let divider = Color.white.opacity(0.08)
    static let primary = Color(hex: 0x7C4DFF)
    static let primaryHover = Color(hex: 0x9A68FF)
    static let success = Color(hex: 0x22C55E)
    static let danger = Color(hex: 0xEF4444)
    static let warning = Color(hex: 0xF59E0B)
    static let info = Color(hex: 0x38BDF8)
    static let text = Color(hex: 0xF3F6FF)
    static let textSecondary = Color(hex: 0x9AA4B2)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(hex: 0x07101E),
            Color(hex: 0x0B1326),
            Color(hex: 0x0B0F19)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [primary, Color(hex: 0x4338CA)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ContentView: View {

    @State private var showingImporter = false
    @State private var selectedFile = "No statement imported"
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @State private var selectedSection: AppShellSection = .dashboard
    @State private var didStartRepositoryHydration = false
    @State private var developerModeEnabled = true

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(LFTheme.divider)
                .frame(width: 1)

            VStack(spacing: 0) {
                contextualToolbar

                Rectangle()
                    .fill(LFTheme.divider)
                    .frame(height: 1)

                content
            }
            .frame(minWidth: 900, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1180, minHeight: 760)
        .background(LFTheme.backgroundGradient)
        .foregroundStyle(LFTheme.text)
        .preferredColorScheme(.dark)
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
            windowControls
                .padding(.bottom, 24)

            HStack(spacing: 12) {
                appMark

                Text("LedgerForge")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 24)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LFTheme.primaryGradient)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Text("VF")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vyom")
                        .font(.subheadline.weight(.semibold))
                    Text("Personal")
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            .padding(.bottom, 22)

            sidebarGroup([.dashboard, .accounts, .transactions, .imports])

            sidebarSeparator

            sidebarGroup([.insights, .budgets, .reports, .investments, .timeline, .intelligence, .automation])

            sidebarSeparator

            sidebarGroup([.settings])

            if developerModeEnabled {
                sidebarButton(.developer)
            }

            Spacer()

            sidebarFooter
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(width: 242)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x070B15), Color(hex: 0x091427)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var contextualToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 27, weight: .semibold))
                Text(toolbarSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(LFTheme.textSecondary)
            }

            Spacer(minLength: 24)

            if selectedSection == .dashboard || selectedSection == .transactions {
                LFSearchField(placeholder: toolbarSearchPlaceholder)
                    .frame(width: selectedSection == .transactions ? 420 : 280)
            }

            toolbarButton("1 Apr - 8 Jul 2026", systemImage: "calendar", disabled: true)
            toolbarButton("Filters", systemImage: "line.3.horizontal.decrease", disabled: true)

            Button {
                showingImporter = true
                selectedSection = .imports
            } label: {
                Label("Import Statement", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minWidth: 176)
                    .background(LFTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(LFTheme.backgroundDeep.opacity(0.72))
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
            importWizardContent
        case .insights, .budgets, .reports, .investments, .timeline, .intelligence, .automation:
            futureModuleContent(selectedSection)
        case .settings:
            settingsContent
        case .developer:
            DeveloperConsoleView()
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    metricCard(
                        title: "Net Worth",
                        value: formatCurrency(dashboardViewModel.snapshot.netWorth),
                        trend: "Repository-backed balance",
                        trendColor: LFTheme.success,
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                    metricCard(
                        title: "Income",
                        value: formatCurrency(dashboardViewModel.snapshot.income),
                        trend: "Credited transactions",
                        trendColor: LFTheme.success,
                        systemImage: "arrow.down.circle"
                    )
                    metricCard(
                        title: "Expenses",
                        value: formatCurrency(dashboardViewModel.snapshot.expenses),
                        trend: "Debited transactions",
                        trendColor: LFTheme.danger,
                        systemImage: "arrow.up.circle"
                    )
                    metricCard(
                        title: "Cash Flow",
                        value: formatCurrency(dashboardViewModel.snapshot.cashFlow),
                        trend: dashboardViewModel.snapshot.cashFlow >= .zero ? "Positive flow" : "Needs review",
                        trendColor: dashboardViewModel.snapshot.cashFlow >= .zero ? LFTheme.success : LFTheme.danger,
                        systemImage: "waveform.path.ecg"
                    )
                }

                HStack(alignment: .top, spacing: 14) {
                    dashboardAccountsCard
                        .frame(maxWidth: .infinity)

                    spendingOverviewCard
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        importActivityCard
                        quickActionsCard
                    }
                    .frame(width: 324)
                }

                HStack(alignment: .top, spacing: 14) {
                    recentTransactionsCard
                        .frame(maxWidth: .infinity)

                    cashFlowTrendCard
                        .frame(width: 324)
                }
            }
            .padding(28)
        }
        .background(LFTheme.backgroundGradient)
    }

    private var accountsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    accountMetric("Total Balance", value: formatCurrency(totalAccountBalance), detail: "Across \(dashboardViewModel.accounts.count) account(s)", icon: "wallet.pass")
                    accountMetric("Cash & Bank", value: formatCurrency(totalAccountBalance), detail: "\(dashboardViewModel.accounts.count) linked account(s)", icon: "building.columns")
                    accountMetric("Credit Cards", value: formatCurrency(.zero), detail: "Planned module", icon: "creditcard", tint: LFTheme.danger)
                    accountMetric("Investments", value: "Future", detail: "Out of Sprint 22 scope", icon: "chart.bar.xaxis", tint: LFTheme.primaryHover)
                }

                HStack(alignment: .top, spacing: 14) {
                    LFPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                LFSearchField(placeholder: "Search accounts...")
                                filterChip("All Types")
                                filterChip("All Institutions")
                                filterChip("All Status")
                            }

                            accountTableHeader

                            if dashboardViewModel.accountSummaries.isEmpty {
                                emptyState(
                                    title: "No accounts found",
                                    message: "Trusted repository-backed accounts appear here after import.",
                                    action: "Import Statement",
                                    systemImage: "wallet.pass"
                                ) {
                                    showingImporter = true
                                    selectedSection = .imports
                                }
                            } else {
                                ForEach(dashboardViewModel.accountSummaries) { account in
                                    accountRow(account)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    accountDetailPanel
                        .frame(width: 344)
                }
            }
            .padding(28)
        }
        .background(LFTheme.backgroundGradient)
    }

    private var importWizardContent: some View {
        VStack(spacing: 18) {
            importStepper

            HStack(alignment: .top, spacing: 18) {
                LFPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upload Files")
                            .font(.title3.weight(.semibold))
                        Text("Supported formats in the current implementation: CSV and spreadsheet exports.")
                            .font(.subheadline)
                            .foregroundStyle(LFTheme.textSecondary)

                        Button {
                            showingImporter = true
                        } label: {
                            VStack(spacing: 14) {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 42, weight: .light))
                                    .foregroundStyle(LFTheme.primaryHover)
                                Text("Drag & drop files here")
                                    .font(.headline)
                                Text("or")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                                Text("Browse Files")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 9)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(LFTheme.primary, lineWidth: 1)
                                    )
                            }
                            .frame(maxWidth: .infinity, minHeight: 210)
                            .background(LFTheme.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LFTheme.primary.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            )
                        }
                        .buttonStyle(.plain)

                        importedFileRow(name: selectedFile, subtitle: selectedFile == "No statement imported" ? "No file selected" : "Ready for current import pipeline", icon: "doc.text", color: LFTheme.info)

                        HStack(spacing: 12) {
                            Image(systemName: "shield.checkered")
                                .foregroundStyle(LFTheme.primaryHover)
                            Text("Files are processed locally. Repository persistence still requires successful validation.")
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                            Spacer()
                        }
                        .padding(12)
                        .background(LFTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                LFPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Import Options")
                            .font(.title3.weight(.semibold))

                        settingsPickerRow("File Password", value: "Resolved by password provider", icon: "lock")
                        settingsPickerRow("Date Format", value: "DD MMM YYYY", icon: "calendar")
                        settingsPickerRow("Duplicate Handling", value: "Skip duplicates", icon: "rectangle.on.rectangle")
                        settingsPickerRow("Create / Link Accounts", value: "Automatically link", icon: "link")
                        settingsPickerRow("Category Detection", value: "Future rules module", icon: "sparkles")

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Smart Detection", systemImage: "star")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(LFTheme.primaryHover)
                            Text("Institution detection, statement classification and parser selection remain deterministic and local.")
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LFTheme.primary.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(LFTheme.primary.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    selectedSection = .dashboard
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 42)
                .padding(.vertical, 13)
                .background(LFTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                Button {
                    showingImporter = true
                } label: {
                    Label("Next", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 13)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .background(LFTheme.backgroundGradient)
    }

    private var settingsContent: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 18) {
                LFPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsCategory("General", icon: "gearshape", selected: true)
                        settingsCategory("Database", icon: "cylinder")
                        settingsCategory("Import", icon: "square.and.arrow.down")
                        settingsCategory("Parsing & Detection", icon: "gauge.with.dots.needle.50percent")
                        settingsCategory("Accounts & Categories", icon: "wallet.pass")
                        settingsCategory("Transactions", icon: "creditcard")
                        settingsCategory("Security & Privacy", icon: "shield")
                        settingsCategory("Appearance", icon: "paintbrush")
                        settingsCategory("Notifications", icon: "bell")
                    }
                }
                .frame(width: 230)

                VStack(spacing: 18) {
                    LFPanel(title: "Application") {
                        VStack(spacing: 0) {
                            settingsPickerRow("Startup Behaviour", value: "Open Dashboard", icon: "macwindow")
                            settingsPickerRow("Default Landing Page", value: "Dashboard", icon: "house")
                            settingsPickerRow("Currency", value: "INR (₹)", icon: "indianrupeesign")
                            settingsPickerRow("Date Format", value: "DD MMM YYYY", icon: "calendar")
                            settingsPickerRow("Number Format", value: "Indian (12,34,567.89)", icon: "textformat.123")
                            settingsToggleRow("Developer Mode", icon: "chevron.left.forwardslash.chevron.right", isOn: $developerModeEnabled)
                        }
                    }

                    LFPanel(title: "Default Settings") {
                        VStack(spacing: 0) {
                            settingsPickerRow("Default Account Type", value: "Savings Account", icon: "wallet.pass")
                            settingsPickerRow("Default Transaction Status", value: "Cleared", icon: "checkmark.circle")
                            settingsPickerRow("Default Category", value: "Uncategorized", icon: "tag")
                            settingsPickerRow("Items Per Page", value: "25", icon: "tablecells")
                        }
                    }
                }

                VStack(spacing: 18) {
                    LFPanel(title: "System Information") {
                        infoRow("Version", value: "1.0.0")
                        infoRow("Environment", value: "Local")
                        infoRow("Database", value: "SQLite")
                        infoRow("Runtime State", value: dashboardViewModel.presentationState.message)
                    }

                    LFPanel(title: "Data Summary") {
                        infoRow("Accounts", value: "\(dashboardViewModel.accounts.count)")
                        infoRow("Transactions", value: "\(dashboardViewModel.transactionCount)")
                        infoRow("Imported Files", value: selectedFile == "No statement imported" ? "0" : "1")
                    }

                    LFPanel(title: "Danger Zone") {
                        dangerRow("Rebuild Search Index", action: "Future")
                        dangerRow("Clear Cached Data", action: "Future")
                        dangerRow("Reset Application", action: "Future")
                    }
                }
                .frame(width: 330)
            }
            .padding(28)
        }
        .background(LFTheme.backgroundGradient)
    }

    private func futureModuleContent(_ section: AppShellSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LFPanel {
                emptyState(
                    title: "\(section.rawValue) is planned",
                    message: "This approved shell reserves navigation for \(section.rawValue), but implementation belongs to a future sprint.",
                    action: "Return to Dashboard",
                    systemImage: section.systemImage
                ) {
                    selectedSection = .dashboard
                }
            }
            .frame(width: 520)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LFTheme.backgroundGradient)
    }

    private var dashboardAccountsCard: some View {
        LFPanel(title: "Accounts", trailing: AnyView(linkButton("View all") { selectedSection = .accounts })) {
            VStack(spacing: 0) {
                if dashboardViewModel.accountSummaries.isEmpty {
                    compactEmptyState("No repository-backed accounts")
                } else {
                    ForEach(dashboardViewModel.accountSummaries) { account in
                        HStack(spacing: 12) {
                            accountIcon(account.institution)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(account.institution) · \(account.currencyCode)")
                                    .font(.caption)
                                    .foregroundStyle(LFTheme.textSecondary)
                            }

                            Spacer()

                            Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        .padding(.vertical, 10)

                        if account.id != dashboardViewModel.accountSummaries.last?.id {
                            Divider().overlay(LFTheme.divider)
                        }
                    }
                }
            }
        }
    }

    private var spendingOverviewCard: some View {
        LFPanel(title: "Spending Overview", trailing: AnyView(Text("View full report").font(.caption).foregroundStyle(LFTheme.primaryHover))) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(LFTheme.surfaceRaised, lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(LFTheme.primaryGradient, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(formatCurrency(dashboardViewModel.snapshot.expenses))
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                        Text("Total Expenses")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                    }
                }
                .frame(width: 170, height: 170)

                VStack(alignment: .leading, spacing: 12) {
                    legendRow("Transfers", value: "39.4%", color: .blue)
                    legendRow("Credit Card Payments", value: "24.4%", color: LFTheme.primary)
                    legendRow("Shopping", value: "8.6%", color: LFTheme.danger)
                    legendRow("Bills & Utilities", value: "7.8%", color: LFTheme.warning)
                    legendRow("Food & Dining", value: "6.6%", color: LFTheme.success)
                }
            }
        }
    }

    private var importActivityCard: some View {
        LFPanel(title: "Import Activity", trailing: AnyView(linkButton("View all imports") { selectedSection = .imports })) {
            VStack(spacing: 12) {
                importActivityRow(
                    title: selectedFile,
                    subtitle: selectedFile == "No statement imported" ? "No recent imports" : "Imported through current pipeline",
                    status: selectedFile == "No statement imported" ? "Idle" : "Success"
                )
                importActivityRow(title: "Repository Hydration", subtitle: dashboardViewModel.presentationState.message, status: dashboardHydrationStatus)
            }
        }
    }

    private var quickActionsCard: some View {
        LFPanel(title: "Quick Actions") {
            VStack(spacing: 4) {
                quickAction("Import Statement", icon: "square.and.arrow.down") {
                    showingImporter = true
                    selectedSection = .imports
                }
                quickAction("Add Account", icon: "plus") {
                    selectedSection = .accounts
                }
                quickAction("View All Transactions", icon: "list.bullet") {
                    selectedSection = .transactions
                }
                quickAction("Open Settings", icon: "gearshape") {
                    selectedSection = .settings
                }
            }
        }
    }

    private var recentTransactionsCard: some View {
        LFPanel(title: "Recent Transactions", trailing: AnyView(linkButton("View all transactions") { selectedSection = .transactions })) {
            VStack(spacing: 0) {
                tableHeader(["Date", "Description", "Account", "Type", "Amount", "Balance"])

                if dashboardViewModel.recentTransactionSummaries.isEmpty {
                    compactEmptyState("No repository-backed transactions")
                } else {
                    ForEach(dashboardViewModel.recentTransactionSummaries) { transaction in
                        HStack(spacing: 14) {
                            Text(formatDate(transaction.date))
                                .frame(width: 84, alignment: .leading)
                            Text(transaction.description)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(transaction.currency)
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 92, alignment: .leading)
                            Text(transaction.isCredit ? "Credit" : "Debit")
                                .foregroundStyle(transaction.isCredit ? LFTheme.success : LFTheme.danger)
                                .frame(width: 68, alignment: .leading)
                            Text(formatSignedCurrency(transaction.amount, isCredit: transaction.isCredit))
                                .foregroundStyle(transaction.isCredit ? LFTheme.success : LFTheme.danger)
                                .monospacedDigit()
                                .frame(width: 112, alignment: .trailing)
                            Text("—")
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 86, alignment: .trailing)
                        }
                        .font(.caption)
                        .padding(.vertical, 12)

                        Divider().overlay(LFTheme.divider)
                    }
                }
            }
        }
    }

    private var cashFlowTrendCard: some View {
        LFPanel(title: "Cash Flow Trend") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach([0.50, 0.72, 0.45, 0.80], id: \.self) { height in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LFTheme.success)
                                .frame(width: 20, height: CGFloat(82 * height))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LFTheme.danger)
                                .frame(width: 20, height: CGFloat(60 * (1.0 - height + 0.25)))
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 116)

                HStack(spacing: 12) {
                    legendRow("Income", value: "", color: LFTheme.success)
                    legendRow("Expenses", value: "", color: LFTheme.danger)
                    legendRow("Cash Flow", value: "", color: LFTheme.primary)
                }
            }
        }
    }

    private var accountDetailPanel: some View {
        LFPanel {
            VStack(alignment: .leading, spacing: 18) {
                if let account = dashboardViewModel.accountSummaries.first {
                    HStack(spacing: 12) {
                        accountIcon(account.institution)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName)
                                .font(.headline)
                            Text(account.institution)
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "star")
                            .foregroundStyle(LFTheme.warning)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current Balance")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                        Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(account.currentBalance >= .zero ? LFTheme.success : LFTheme.danger)
                            .monospacedDigit()
                    }

                    infoRow("Institution", value: account.institution)
                    infoRow("Account Type", value: "Repository account")
                    infoRow("Currency", value: account.currencyCode)
                    infoRow("Status", value: "Active")

                    Divider().overlay(LFTheme.divider)

                    Text("Recent Activity")
                        .font(.headline)

                    ForEach(dashboardViewModel.recentTransactionSummaries.prefix(3)) { transaction in
                        HStack {
                            Image(systemName: transaction.isCredit ? "arrow.down" : "arrow.up")
                                .foregroundStyle(transaction.isCredit ? LFTheme.success : LFTheme.danger)
                                .frame(width: 28, height: 28)
                                .background((transaction.isCredit ? LFTheme.success : LFTheme.danger).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(transaction.description)
                                .lineLimit(1)
                            Spacer()
                            Text(formatSignedCurrency(transaction.amount, isCredit: transaction.isCredit))
                                .foregroundStyle(transaction.isCredit ? LFTheme.success : LFTheme.danger)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                } else {
                    compactEmptyState("Select an account after importing trusted data")
                }
            }
        }
    }

    private var importStepper: some View {
        HStack(spacing: 14) {
            wizardStep(1, title: "Select Files", subtitle: "Choose files to import", active: true)
            stepLine(active: true)
            wizardStep(2, title: "Detect & Review", subtitle: "Detect institution", active: false)
            stepLine(active: false)
            wizardStep(3, title: "Map & Validate", subtitle: "Confirm data", active: false)
            stepLine(active: false)
            wizardStep(4, title: "Preview", subtitle: "Review transactions", active: false)
            stepLine(active: false)
            wizardStep(5, title: "Import", subtitle: "Complete import", active: false)
        }
        .padding(.vertical, 10)
    }

    private var totalAccountBalance: Decimal {
        dashboardViewModel.accountSummaries.reduce(.zero) { $0 + $1.currentBalance }
    }

    private var accountTableHeader: some View {
        HStack(spacing: 12) {
            Text("Account Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Institution")
                .frame(width: 160, alignment: .leading)
            Text("Type")
                .frame(width: 100, alignment: .leading)
            Text("Balance")
                .frame(width: 140, alignment: .trailing)
            Text("Status")
                .frame(width: 92, alignment: .leading)
        }
        .font(.caption)
        .foregroundStyle(LFTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var windowControls: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: 0xFF5F57)).frame(width: 12, height: 12)
            Circle().fill(Color(hex: 0xFFBD2E)).frame(width: 12, height: 12)
            Circle().fill(Color(hex: 0x28C840)).frame(width: 12, height: 12)
        }
    }

    private var appMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LFTheme.primaryGradient)
                .frame(width: 34, height: 34)
            Image(systemName: "hexagon.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.92))
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(LFTheme.backgroundDeep)
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Last import")
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
                Text(selectedFile == "No statement imported" ? "No recent import" : selectedFile)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Label(dashboardViewModel.presentationState.message, systemImage: dashboardStatusIcon)
                    .font(.caption2)
                    .foregroundStyle(dashboardStatusColor)
                    .lineLimit(2)
            }

            Divider().overlay(LFTheme.divider)

            Label("Collapse", systemImage: "chevron.left")
                .font(.subheadline)
                .foregroundStyle(LFTheme.textSecondary)
        }
        .padding(.bottom, 4)
    }

    private var sidebarSeparator: some View {
        Rectangle()
            .fill(LFTheme.divider)
            .frame(height: 1)
            .padding(.vertical, 14)
    }

    private func sidebarGroup(_ sections: [AppShellSection]) -> some View {
        VStack(spacing: 5) {
            ForEach(sections, id: \.self) { section in
                sidebarButton(section)
            }
        }
    }

    private func sidebarButton(_ section: AppShellSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                Text(section.rawValue)
                    .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                if section.isFutureModule {
                    Text("Soon")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(LFTheme.primary.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedSection == section ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? .white : LFTheme.text)
    }

    private func toolbarButton(_ title: String, systemImage: String, disabled: Bool = false) -> some View {
        Button {
            // Contextual controls are visual placeholders until their feature sprints.
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(LFTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LFTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? LFTheme.textSecondary : LFTheme.text)
        .disabled(disabled)
    }

    private func metricCard(title: String, value: String, trend: String, trendColor: Color, systemImage: String) -> some View {
        LFPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: systemImage)
                        .foregroundStyle(LFTheme.primaryHover)
                }
                Text(value)
                    .font(.system(size: 25, weight: .semibold))
                    .monospacedDigit()
                Text(trend)
                    .font(.caption)
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accountMetric(_ title: String, value: String, detail: String, icon: String, tint: Color = LFTheme.primary) -> some View {
        LFPanel {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(value)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tint == LFTheme.danger ? LFTheme.danger : LFTheme.text)
                        .monospacedDigit()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accountRow(_ account: DashboardAccountSummary) -> some View {
        HStack(spacing: 12) {
            accountIcon(account.institution)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(account.id.uuidString.prefix(12))
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(account.institution)
                .frame(width: 160, alignment: .leading)

            statusBadge("Bank", color: LFTheme.primary)
                .frame(width: 100, alignment: .leading)

            Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                .foregroundStyle(account.currentBalance >= .zero ? LFTheme.success : LFTheme.danger)
                .monospacedDigit()
                .frame(width: 140, alignment: .trailing)

            statusBadge("Active", color: LFTheme.success)
                .frame(width: 92, alignment: .leading)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(LFTheme.surface.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func accountIcon(_ institution: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(institution.localizedCaseInsensitiveContains("axis") ? Color(hex: 0xB0165B) : LFTheme.primary.opacity(0.55))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: institution.localizedCaseInsensitiveContains("axis") ? "a.square.fill" : "building.columns.fill")
                    .foregroundStyle(.white)
            }
    }

    private func importedFileRow(name: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            Spacer()
            Image(systemName: name == "No statement imported" ? "circle" : "checkmark.circle.fill")
                .foregroundStyle(name == "No statement imported" ? LFTheme.textSecondary : LFTheme.success)
        }
        .padding(14)
        .background(LFTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func settingsPickerRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
        }
        .padding(.vertical, 11)
    }

    private func settingsToggleRow(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 11)
    }

    private func settingsCategory(_ title: String, icon: String, selected: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
            Text(title)
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(selected ? .white : LFTheme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(selected ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func dangerRow(_ title: String, action: String) -> some View {
        HStack {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.caption)
            Spacer()
            Text(action)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LFTheme.warning)
        }
        .padding(.vertical, 8)
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(LFTheme.textSecondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .padding(.vertical, 6)
    }

    private func filterChip(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LFTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(LFTheme.border, lineWidth: 1))
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

    private func tableHeader(_ titles: [String]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .frame(
                        maxWidth: index == 1 ? .infinity : nil,
                        alignment: index >= 4 ? .trailing : .leading
                    )
                    .frame(width: fixedHeaderWidth(index), alignment: index >= 4 ? .trailing : .leading)
            }
        }
        .font(.caption)
        .foregroundStyle(LFTheme.textSecondary)
        .padding(.vertical, 10)
    }

    private func fixedHeaderWidth(_ index: Int) -> CGFloat? {
        switch index {
        case 0:
            return 84
        case 2:
            return 92
        case 3:
            return 68
        case 4:
            return 112
        case 5:
            return 86
        default:
            return nil
        }
    }

    private func compactEmptyState(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(LFTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }

    private func emptyState(title: String, message: String, action: String, systemImage: String, perform: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(LFTheme.primaryHover)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(LFTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button(action) {
                perform()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(LFTheme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(LFTheme.primaryHover)
    }

    private func importActivityRow(title: String, subtitle: String, status: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(LFTheme.info)
                .frame(width: 34, height: 34)
                .background(LFTheme.info.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(LFTheme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            statusBadge(status, color: status == "Success" || status == "Loaded" ? LFTheme.success : LFTheme.textSecondary)
        }
    }

    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(LFTheme.textSecondary)
            }
            .font(.subheadline)
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func legendRow(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.caption)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
        }
    }

    private func wizardStep(_ number: Int, title: String, subtitle: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.headline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(active ? AnyShapeStyle(LFTheme.primaryGradient) : AnyShapeStyle(LFTheme.surface))
                .overlay(Circle().stroke(active ? LFTheme.primaryHover : LFTheme.border, lineWidth: 1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(active ? LFTheme.primaryHover : LFTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LFTheme.textSecondary)
            }
        }
    }

    private func stepLine(active: Bool) -> some View {
        Rectangle()
            .fill(active ? LFTheme.primary : LFTheme.border)
            .frame(maxWidth: .infinity, maxHeight: 2)
    }

    private var toolbarSubtitle: String {
        switch selectedSection {
        case .dashboard:
            return "Here's your financial overview"
        case .accounts:
            return "All your financial accounts in one place"
        case .transactions:
            return "All your transactions, in one place"
        case .imports:
            return "Import statements in a few simple steps"
        case .insights, .budgets, .reports, .investments, .timeline, .intelligence, .automation:
            return "Reserved for future modules"
        case .settings:
            return "Configure LedgerForge to work the way you do"
        case .developer:
            return "Advanced diagnostics and inspection"
        }
    }

    private var toolbarSearchPlaceholder: String {
        switch selectedSection {
        case .transactions:
            return "Search transactions, merchants, categories, or notes..."
        default:
            return "Search..."
        }
    }

    private var dashboardHydrationStatus: String {
        switch dashboardViewModel.presentationState {
        case .loaded:
            return "Loaded"
        case .loading:
            return "Loading"
        case .empty:
            return "Idle"
        case .failed:
            return "Review"
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
            return LFTheme.textSecondary
        case .loaded:
            return LFTheme.success
        case .failed:
            return LFTheme.warning
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

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Decimal, currencyCode: String = "₹") -> String {
        let number = NSDecimalNumber(decimal: value)
        return "\(currencyCode == "INR" ? "₹" : currencyCode) \(Self.numberFormatter.string(from: number) ?? "\(number)")"
    }

    private func formatSignedCurrency(_ value: Decimal, isCredit: Bool) -> String {
        let prefix = isCredit ? "+" : "-"
        let magnitude = value < .zero ? -value : value
        return "\(prefix)\(formatCurrency(magnitude))"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct LFPanel<Content: View>: View {
    let title: String?
    let trailing: AnyView?
    @ViewBuilder let content: Content

    init(title: String? = nil, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || trailing != nil {
                HStack {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    Spacer()
                    trailing
                }
            }

            content
        }
        .padding(16)
        .background(LFTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LFTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LFSearchField: View {
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LFTheme.textSecondary)
            Text(placeholder)
                .font(.subheadline)
                .foregroundStyle(LFTheme.textSecondary)
            Spacer()
            Text("⌘K")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LFTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(LFTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
