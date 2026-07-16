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

private enum ImportPresentationState {
    case idle
    case preparing(fileName: String, phase: ImportProgressPhase)
    case previewReady(PreparedImport)
    case validationFailed(PreparedImport)
    case committing(PreparedImport)
    case completed(ImportOutcomePresentation)
    case cancelled(fileName: String)
    case failed(fileName: String, message: String, retrySourceURL: URL?)
}

private extension ImportPresentationState {
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        default:
            return false
        }
    }

    var showsPreConfirmationNoWriteMessage: Bool {
        switch self {
        case .completed:
            return false
        default:
            return true
        }
    }
}

enum ImportOutcomeTone: Equatable {
    case success
    case warning
    case danger

    var color: Color {
        switch self {
        case .success:
            return LFTheme.success
        case .warning:
            return LFTheme.warning
        case .danger:
            return LFTheme.danger
        }
    }
}

struct ImportOutcomePresentation: Equatable {
    let fileName: String
    let transactionCount: Int
    let validationStatus: String
    let persistenceStatus: String
    let message: String?
    let allowsViewingTransactions: Bool
    let iconName: String
    let tone: ImportOutcomeTone
    let accountId: String?
    let importSessionId: String?
    let redactedIdentifier: String?
    let previousImportCompletedAtISO: String?
    let previousAccountDisplayName: String?
    let isPreviouslyImported: Bool
    let transactionEventBlock: TransactionEventBlock?

    init(result: ImportEngineResult) {
        fileName = result.fileName
        transactionCount = result.transactionCount
        validationStatus = result.validationPassed ? "Validation Passed" : "Validation Failed"
        allowsViewingTransactions = result.validationPassed && result.persisted
        accountId = result.accountId
        importSessionId = result.importSessionId
        redactedIdentifier = result.redactedIdentifier
        previousImportCompletedAtISO = result.previousImport?.completedAtISO
        previousAccountDisplayName = result.previousImport?.accountDisplayName
        isPreviouslyImported = result.previousImport != nil
        transactionEventBlock = result.transactionEventBlock

        if result.previousImport != nil || result.transactionEventBlock != nil || result.persisted {
            message = result.errorMessage?.isEmpty == false ? result.errorMessage : nil
        } else {
            let failure = result.validationPassed ? "Import persistence failed." : "Import validation failed."
            let history = result.importAttemptId != nil
                ? "The failure was added to Import History."
                : "The failure could not be added to Import History."
            message = "\(failure) \(history)"
        }

        if result.previousImport != nil {
            persistenceStatus = "Previously Imported"
            iconName = "doc.badge.checkmark.fill"
            tone = .warning
        } else if result.transactionEventBlock != nil {
            persistenceStatus = "Statement Blocked"
            iconName = "exclamationmark.triangle.fill"
            tone = .warning
        } else if result.validationPassed && result.persisted {
            persistenceStatus = "Persistence Succeeded"
            iconName = "checkmark.circle.fill"
            tone = .success
        } else if result.validationPassed {
            persistenceStatus = "Persistence Failed"
            iconName = "exclamationmark.triangle.fill"
            tone = .warning
        } else {
            persistenceStatus = "Not Persisted"
            iconName = "xmark.octagon.fill"
            tone = .danger
        }
    }

    var fileSubtitle: String {
        if isPreviouslyImported {
            return "Previously imported — no new data written"
        }
        if allowsViewingTransactions {
            return "Imported \(transactionCount) transaction(s)"
        }

        return "Processed \(transactionCount) transaction(s)"
    }
}

struct ContentView: View {

    @State private var showingImporter = false
    @State private var selectedFile = "No statement imported"
    @State private var importState: ImportPresentationState = .idle
    @State private var preparationOwner = ImportPreparationTaskOwner()
    @State private var importIdentityReview: ImportIdentityReview = .unavailable
    @State private var importAccountChoice: ImportAccountChoice?
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var accountsViewModel = AccountsViewModel()
    @StateObject private var importHistoryViewModel = ImportHistoryViewModel()
    @State private var selectedSection: AppShellSection = .dashboard
    @State private var didStartRepositoryHydration = false
    @State private var developerModeEnabled = false

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
                beginPreparation(from: url)

            case .failure(let error):
                selectedFile = error.localizedDescription
                importState = .failed(fileName: "Import failed", message: error.localizedDescription, retrySourceURL: nil)
                selectedSection = .imports
            }
        }
        .task {
            hydrateDashboardOnce()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            toolbarButton("Date range pending", systemImage: "calendar", disabled: true)
            toolbarButton("Filters pending", systemImage: "line.3.horizontal.decrease", disabled: true)

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
                    ForEach(dashboardViewModel.nativeCurrencySummaries) { summary in
                        metricCard(title: "\(summary.currency.code) Balance", value: MoneyFormatting.display(summary.balance), trend: "Repository-backed native balance", trendColor: LFTheme.success, systemImage: "chart.line.uptrend.xyaxis")
                        metricCard(title: "\(summary.currency.code) Inflow", value: MoneyFormatting.display(summary.income), trend: "Credited transactions", trendColor: LFTheme.success, systemImage: "arrow.down.circle")
                        metricCard(title: "\(summary.currency.code) Outflow", value: MoneyFormatting.display(summary.expenses), trend: "Debited transactions", trendColor: LFTheme.danger, systemImage: "arrow.up.circle")
                        metricCard(title: "\(summary.currency.code) Cash Flow", value: MoneyFormatting.display(summary.cashFlow), trend: summary.cashFlow.amount >= .zero ? "Positive flow" : "Needs review", trendColor: summary.cashFlow.amount >= .zero ? LFTheme.success : LFTheme.danger, systemImage: "waveform.path.ecg")
                    }
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
                    ForEach(accountsViewModel.nativeBalanceSummaries) { summary in
                        accountMetric("\(summary.money.currency.code) Balance", value: MoneyFormatting.display(summary.money), detail: "Native total across \(accountsViewModel.accounts.count) account(s)", icon: "wallet.pass")
                    }
                    accountMetric("Credit Cards", value: "Not enabled", detail: "Planned module", icon: "creditcard", tint: LFTheme.danger)
                    accountMetric("Investments", value: "Future", detail: "Out of Sprint 22 scope", icon: "chart.bar.xaxis", tint: LFTheme.primaryHover)
                }

                HStack(alignment: .top, spacing: 14) {
                    LFPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                LFSearchField(placeholder: "Search accounts...")
                                LFFilterChip(title: "Types", value: "Pending", showsChevron: false)
                                LFFilterChip(title: "Institutions", value: "Pending", showsChevron: false)
                                LFFilterChip(title: "Status", value: "Pending", showsChevron: false)
                            }

                            accountTableHeader

                            if accountsViewModel.accounts.isEmpty {
                                LFEmptyState(
                                    title: "No accounts found",
                                    message: "Trusted repository-backed accounts appear here after import.",
                                    actionTitle: "Import Statement",
                                    systemImage: "wallet.pass"
                                ) {
                                    showingImporter = true
                                    selectedSection = .imports
                                }
                            } else {
                                ForEach(accountsViewModel.accounts) { account in
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Prepare Statement")
                                .font(.title3.weight(.semibold))
                            Text("Choose a file, review the parsed statement and confirm before LedgerForge writes financial data.")
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
                            .disabled(importSelectionDisabled)

                            importResultPanel

                            importAttemptHistoryPanel

                            if importState.showsPreConfirmationNoWriteMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(LFTheme.info)
                                    Text("No data is written until Confirm Import is selected.")
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(12)
                                .background(LFTheme.info.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LFTheme.info.opacity(0.25), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

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
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                LFPanel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Validation Review")
                                .font(.title3.weight(.semibold))

                            validationReviewPanel
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxHeight: .infinity)

            HStack {
                if case .committing = importState {
                    Label("Cancellation unavailable", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LFTheme.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(LFTheme.surface.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Button {
                        cancelPreparedImport()
                    } label: {
                        Text("Cancel")
                            .padding(.horizontal, 42)
                            .padding(.vertical, 13)
                            .background(LFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCancelPreparation)
                }

                Spacer()

                importFooterAction
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                            settingsPendingRow("Startup Behaviour", value: "Open Dashboard", icon: "macwindow")
                            settingsPendingRow("Default Landing Page", value: "Dashboard", icon: "house")
                            settingsPendingRow("Currency", value: "INR (₹)", icon: "indianrupeesign")
                            settingsPendingRow("Date Format", value: "DD MMM YYYY", icon: "calendar")
                            settingsPendingRow("Number Format", value: "Indian (12,34,567.89)", icon: "textformat.123")
                            settingsToggleRow("Developer Mode", icon: "chevron.left.forwardslash.chevron.right", isOn: $developerModeEnabled)
                        }
                    }

                    LFPanel(title: "Default Settings") {
                        VStack(spacing: 0) {
                            settingsPendingRow("Default Account Type", value: "Savings Account", icon: "wallet.pass")
                            settingsPendingRow("Default Transaction Status", value: "Cleared", icon: "checkmark.circle")
                            settingsPendingRow("Default Category", value: "Uncategorized", icon: "tag")
                            settingsPendingRow("Items Per Page", value: "25", icon: "tablecells")
                        }
                    }
                }

                VStack(spacing: 18) {
                    LFPanel(title: "System Information") {
                        LFInfoRow(title: "Version", value: "1.0.0")
                        LFInfoRow(title: "Environment", value: "Local")
                        LFInfoRow(title: "Database", value: "SQLite")
                        LFInfoRow(title: "Runtime State", value: dashboardViewModel.presentationState.message)
                    }

                    LFPanel(title: "Data Summary") {
                        LFInfoRow(title: "Accounts", value: "\(dashboardViewModel.accounts.count)")
                        LFInfoRow(title: "Transactions", value: "\(dashboardViewModel.transactionCount)")
                        LFInfoRow(title: "Imported Files", value: selectedFile == "No statement imported" ? "0" : "1")
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
                LFEmptyState(
                    title: "\(section.rawValue) is planned",
                    message: "This approved shell reserves navigation for \(section.rawValue), but implementation belongs to a future sprint.",
                    actionTitle: "Return to Dashboard",
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
                    LFCompactEmptyState(message: "No repository-backed accounts")
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
                LFActionRow(title: "Import Statement", systemImage: "square.and.arrow.down") {
                    showingImporter = true
                    selectedSection = .imports
                }
                LFActionRow(title: "Add Account", systemImage: "plus") {
                    selectedSection = .accounts
                }
                LFActionRow(title: "View All Transactions", systemImage: "list.bullet") {
                    selectedSection = .transactions
                }
                LFActionRow(title: "Open Settings", systemImage: "gearshape") {
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
                    LFCompactEmptyState(message: "No repository-backed transactions")
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
                if let account = accountsViewModel.selectedAccount {
                    HStack(spacing: 12) {
                        accountIcon(account.institution)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            if accountsViewModel.isEditingDisplayName {
                                TextField("Display name", text: $accountsViewModel.displayNameDraft)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Text(account.displayName)
                                    .font(.headline)
                            }
                            Text(account.institution)
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "star")
                            .foregroundStyle(LFTheme.warning)
                    }

                    if accountsViewModel.isEditingDisplayName {
                        HStack(spacing: 10) {
                            Button("Save") {
                                accountsViewModel.saveDisplayName()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Cancel") {
                                accountsViewModel.cancelDisplayNameEdit()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Edit display name") {
                            accountsViewModel.beginDisplayNameEdit()
                        }
                        .buttonStyle(.bordered)
                    }

                    if let message = accountsViewModel.presentationState.message {
                        Text(message)
                            .font(.caption)
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

                    LFInfoRow(title: "Institution", value: account.institution)
                    LFInfoRow(title: "Account Type", value: account.accountTypeLabel)
                    LFInfoRow(title: "Currency", value: account.currencyCode)
                    LFInfoRow(title: "Transactions", value: "\(accountsViewModel.transactionCount)")

                    Divider().overlay(LFTheme.divider)

                    Text("Recent Activity")
                        .font(.headline)

                    if accountsViewModel.recentActivity.isEmpty {
                        LFCompactEmptyState(message: "No trusted activity for this account")
                    }

                    ForEach(accountsViewModel.recentActivity) { transaction in
                        HStack {
                            Image(systemName: transaction.credit != nil ? "arrow.down" : "arrow.up")
                                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                                .frame(width: 28, height: 28)
                                .background((transaction.credit != nil ? LFTheme.success : LFTheme.danger).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(transaction.description)
                                .lineLimit(1)
                            Spacer()
                            Text(formatSignedCurrency(transaction.amount, isCredit: transaction.credit != nil))
                                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }

                    Divider().overlay(LFTheme.divider)

                    Text("Verified Financial Identity")
                        .font(.headline)
                    if account.identitySummaries.isEmpty {
                        LFCompactEmptyState(message: "No verified strong identifiers")
                    } else {
                        ForEach(account.identitySummaries) { identifier in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(identifier.kind) · \(identifier.redactedValue)")
                                    .font(.caption.weight(.semibold))
                                Text("\(identifier.strength) · \(identifier.verificationState) · \(identifier.provenance)")
                                    .font(.caption2)
                                    .foregroundStyle(LFTheme.textSecondary)
                            }
                        }
                    }

                    Divider().overlay(LFTheme.divider)

                    Text("Import History")
                        .font(.headline)
                    if accountsViewModel.importHistory.isEmpty {
                        LFCompactEmptyState(message: "No trusted import history for this account")
                    } else {
                        ForEach(accountsViewModel.importHistory) { session in
                            Button {
                                accountsViewModel.selectImportSession(id: session.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.sourceDocumentName ?? "Imported statement")
                                        .font(.caption.weight(.semibold))
                                    Text("\(session.validationStatus) · \(session.transactionCount) transaction(s)")
                                        .font(.caption2)
                                        .foregroundStyle(LFTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let session = accountsViewModel.selectedImportSession {
                        Divider().overlay(LFTheme.divider)
                        HStack {
                            Text("Import Detail")
                                .font(.headline)
                            Spacer()
                            Button("Close") {
                                accountsViewModel.clearSelectedImportSession()
                            }
                            .buttonStyle(.bordered)
                        }
                        LFInfoRow(title: "Source", value: session.sourceDocumentName ?? "Imported statement")
                        LFInfoRow(title: "Status", value: session.validationStatus)
                        LFInfoRow(title: "Transactions", value: "\(session.transactionCount)")
                        if let parserVersion = session.parserVersion {
                            LFInfoRow(title: "Parser", value: parserVersion)
                        }
                    }
                } else {
                    LFCompactEmptyState(message: "Select an account after importing trusted data")
                }
            }
        }
    }

    private var importStepper: some View {
        HStack(spacing: 14) {
            wizardStep(1, title: "Choose File", subtitle: "Select statement", active: importStep >= 1)
            stepLine(active: importStep >= 2)
            wizardStep(2, title: "Prepare", subtitle: "Read and validate", active: importStep >= 2)
            stepLine(active: importStep >= 3)
            wizardStep(3, title: "Preview", subtitle: "Read-only review", active: importStep >= 3)
            stepLine(active: importStep >= 4)
            wizardStep(4, title: "Confirm", subtitle: "Explicit commit", active: importStep >= 4)
            stepLine(active: importStep >= 5)
            wizardStep(5, title: "Import", subtitle: "Complete import", active: importStep >= 5)
        }
        .padding(.vertical, 10)
    }

    private var importStep: Int {
        switch importState {
        case .idle:
            return 1
        case .preparing:
            return 2
        case .previewReady, .validationFailed:
            return 3
        case .committing:
            return 4
        case .completed:
            return 5
        case .failed:
            return 2
        case .cancelled:
            return 1
        }
    }

    private var importSelectionDisabled: Bool {
        switch importState {
        case .preparing, .committing:
            return true
        default:
            return false
        }
    }

    private var canCancelPreparation: Bool {
        switch importState {
        case .preparing, .previewReady, .validationFailed:
            return true
        default:
            return false
        }
    }

    private var totalAccountBalance: Decimal {
        accountsViewModel.accounts.reduce(.zero) { $0 + $1.currentBalance }
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
        }
        .font(.caption)
        .foregroundStyle(LFTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? .white : LFTheme.text)
        .accessibilityLabel(section.rawValue)
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

    private func accountRow(_ account: AccountsAccountPresentation) -> some View {
        Button {
            accountsViewModel.selectAccount(repositoryAccountID: account.id)
        } label: {
            HStack(spacing: 12) {
                accountIcon(account.institution)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(account.currencyCode)
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(account.institution)
                    .frame(width: 160, alignment: .leading)

                LFStatusBadge(title: account.accountTypeLabel, color: LFTheme.primary)
                    .frame(width: 100, alignment: .leading)

                Text(formatCurrency(account.currentBalance, currencyCode: account.currencyCode))
                    .foregroundStyle(account.currentBalance >= .zero ? LFTheme.success : LFTheme.danger)
                    .monospacedDigit()
                    .frame(width: 140, alignment: .trailing)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .background(
                accountsViewModel.selectedRepositoryAccountID == account.id
                    ? LFTheme.primary.opacity(0.16)
                    : LFTheme.surface.opacity(0.45)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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

    private var importResultPanel: some View {
        Group {
            switch importState {
            case .idle:
                importedFileRow(
                    name: selectedFile,
                    subtitle: "No file selected",
                    icon: "doc.text",
                    color: LFTheme.info
                )
            case .preparing(let fileName, let phase):
                VStack(alignment: .leading, spacing: 12) {
                    importedFileRow(
                        name: fileName,
                        subtitle: phase.userFacingTitle,
                        icon: "hourglass",
                        color: LFTheme.warning
                    )
                    ProgressView()
                        .controlSize(.small)
                    Text("Preparing a read-only preview. You can cancel before confirmation.")
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                }
            case .previewReady(let preparedImport), .validationFailed(let preparedImport), .committing(let preparedImport):
                VStack(alignment: .leading, spacing: 10) {
                    preparedImportPreview(preparedImport)
                    if case .committing = importState {
                        Text("Importing confirmed financial data. This write cannot be cancelled safely.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LFTheme.warning)
                    }
                }
            case .completed(let outcome):
                VStack(alignment: .leading, spacing: 12) {
                    importedFileRow(
                        name: outcome.fileName,
                        subtitle: outcome.fileSubtitle,
                        icon: outcome.iconName,
                        color: outcome.tone.color
                    )

                    HStack(spacing: 8) {
                        LFStatusBadge(
                            title: outcome.validationStatus,
                            color: outcome.validationStatus == "Validation Passed" ? LFTheme.success : LFTheme.danger
                        )
                        LFStatusBadge(title: outcome.persistenceStatus, color: outcome.tone.color)
                    }

                    LFInfoRow(title: "Transactions", value: "\(outcome.transactionCount)")

                    if outcome.isPreviouslyImported {
                        if let completedAtISO = outcome.previousImportCompletedAtISO {
                            LFInfoRow(title: "Prior Import", value: completedAtISO)
                        }
                        if let accountName = outcome.previousAccountDisplayName {
                            LFInfoRow(title: "Account", value: accountName)
                        }
                        Text("This exact statement was imported previously. LedgerForge did not write another document, import session, transaction, account, or identifier.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LFTheme.warning.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let message = outcome.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if outcome.allowsViewingTransactions {
                        if let accountId = outcome.accountId,
                           let account = accountsViewModel.accounts.first(where: { $0.id == accountId }) {
                            LFInfoRow(title: "Verified Account", value: account.displayName)
                        }
                        if let redactedIdentifier = outcome.redactedIdentifier {
                            LFInfoRow(title: "Verified Identifier", value: redactedIdentifier)
                        }
                        if outcome.importSessionId != nil {
                            LFInfoRow(title: "Import Session", value: "Persisted")
                        }
                    }

                    if outcome.allowsViewingTransactions || outcome.isPreviouslyImported {
                        if let accountId = outcome.accountId,
                           accountsViewModel.accounts.contains(where: { $0.id == accountId }) {
                            Button {
                                accountsViewModel.selectAccount(repositoryAccountID: accountId)
                                selectedSection = .accounts
                            } label: {
                                Label("View Account", systemImage: "person.crop.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(LFTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(LFTheme.text)
                        }
                        if outcome.allowsViewingTransactions {
                            Button {
                                selectedSection = .transactions
                            } label: {
                                Label("View Transactions", systemImage: "list.bullet")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(LFTheme.primaryGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            case .cancelled(let fileName):
                importedFileRow(
                    name: fileName,
                    subtitle: "Preparation cancelled. No data was written.",
                    icon: "xmark.circle.fill",
                    color: LFTheme.textSecondary
                )
            case .failed(let fileName, let message, let retrySourceURL):
                VStack(alignment: .leading, spacing: 10) {
                    importedFileRow(
                        name: fileName,
                        subtitle: message,
                        icon: "exclamationmark.triangle.fill",
                        color: LFTheme.danger
                    )
                    if retrySourceURL != nil {
                        Text("The source could not be read. You can retry from the beginning.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var importAttemptHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Import History").font(.headline)
                Spacer()
                Text("\(importHistoryViewModel.attempts.count)").font(.caption).foregroundStyle(LFTheme.textSecondary)
            }
            if importHistoryViewModel.attempts.isEmpty {
                Text("Supported import outcomes appear here after processing.")
                    .font(.caption).foregroundStyle(LFTheme.textSecondary)
            } else {
                ForEach(importHistoryViewModel.attempts.prefix(8)) { attempt in
                    Button { importHistoryViewModel.select(id: attempt.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attemptTitle(attempt.outcomeCode)).font(.subheadline.weight(.semibold))
                                Text(attempt.createdAtISO).font(.caption2).foregroundStyle(LFTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(attempt.transactionCount) transactions").font(.caption).foregroundStyle(LFTheme.textSecondary)
                        }
                        .padding(9).background(LFTheme.surface.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
            }
            if let attempt = importHistoryViewModel.selectedAttempt {
                Divider()
                HStack { Text("Attempt Detail").font(.subheadline.weight(.semibold)); Spacer(); Button("Close") { importHistoryViewModel.clearSelection() }.font(.caption) }
                LFInfoRow(title: "Outcome", value: attemptTitle(attempt.outcomeCode))
                LFInfoRow(title: "Coverage", value: attempt.coverageCode.replacingOccurrences(of: "_", with: " "))
                LFInfoRow(title: "Guidance", value: attempt.guidanceCode.replacingOccurrences(of: "_", with: " "))
                if let accountID = attempt.accountId, accountsViewModel.accounts.contains(where: { $0.id == accountID }) {
                    Button("View Account") { accountsViewModel.selectAccount(repositoryAccountID: accountID); selectedSection = .accounts }
                        .font(.caption.weight(.semibold)).buttonStyle(.plain).foregroundStyle(LFTheme.primaryHover)
                }
            }
        }
        .padding(12).background(LFTheme.surface.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func attemptTitle(_ code: String) -> String {
        switch code {
        case ImportAttemptOutcome.successfulImport.rawValue: return "Import completed"
        case ImportAttemptOutcome.validationFailure.rawValue: return "Validation failed"
        case ImportAttemptOutcome.exactStatementDuplicate.rawValue: return "Previously imported"
        case ImportAttemptOutcome.existingEligibleAxisUPIEvent.rawValue: return "Supported transaction event blocked"
        case ImportAttemptOutcome.repeatedEligibleIncomingEvidence.rawValue: return "Repeated incoming evidence"
        case ImportAttemptOutcome.transactionEventOwnershipConflict.rawValue: return "Transaction-event ownership conflict"
        case ImportAttemptOutcome.repositoryIntegrityConflict.rawValue: return "Repository integrity conflict"
        default: return "Persistence failed"
        }
    }

    private func preparedImportPreview(_ preparedImport: PreparedImport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            importedFileRow(
                name: preparedImport.fileName,
                subtitle: preparedImport.validation.passed ? "Prepared for confirmation" : "Validation failed before persistence",
                icon: preparedImport.validation.passed ? "doc.text.magnifyingglass" : "xmark.octagon.fill",
                color: preparedImport.validation.passed ? LFTheme.success : LFTheme.danger
            )

            HStack(spacing: 8) {
                LFStatusBadge(title: preparedImport.detectedInstitution.rawValue, color: LFTheme.primary)
                LFStatusBadge(title: preparedImport.detectedDocumentType.rawValue, color: LFTheme.info)
                LFStatusBadge(title: preparedImport.parserName, color: LFTheme.textSecondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                LFInfoRow(title: "Transactions", value: "\(preparedImport.transactionCount)")
                LFInfoRow(title: "Currency", value: preparedImport.detectedCurrency ?? "Unknown")
                LFInfoRow(title: "Account", value: preparedImport.accountMetadata ?? "Unknown")
                LFInfoRow(title: "Statement Period", value: statementPeriodText(preparedImport.statementPeriod))
                LFInfoRow(title: "Opening Balance", value: balanceText(preparedImport.validation.openingBalance, currency: preparedImport.detectedCurrency))
                LFInfoRow(title: "Closing Balance", value: balanceText(preparedImport.validation.closingBalance, currency: preparedImport.detectedCurrency))
            }

            if importIdentityReview.isAvailable {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose Account")
                        .font(.subheadline.weight(.semibold))
                    Text("Choose where this verified identity will be attached. No account is selected automatically.")
                        .font(.caption)
                        .foregroundStyle(LFTheme.textSecondary)
                    ForEach(accountsViewModel.accounts.filter { importIdentityReview.eligibleAccountIds.contains($0.id) }) { account in
                        Button {
                            importAccountChoice = .useExistingAccount(accountId: account.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.displayName)
                                    Text(account.institution)
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: importAccountChoice == .useExistingAccount(accountId: account.id) ? "checkmark.circle.fill" : "circle")
                            }
                            .padding(10)
                            .background(LFTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(LFTheme.text)
                    }
                    Button {
                        importAccountChoice = .createNewAccount
                    } label: {
                        HStack {
                            Text("Create New Account")
                            Spacer()
                            Image(systemName: importAccountChoice == .createNewAccount ? "checkmark.circle.fill" : "circle")
                        }
                        .padding(10)
                        .background(LFTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(LFTheme.text)
                }
                .padding(12)
                .background(LFTheme.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Preview")
                    .font(.subheadline.weight(.semibold))
                tableHeader(["Date", "Description", "Currency", "Type", "Amount", "Balance"])
                ForEach(preparedImport.financialDocument.transactions.prefix(12)) { transaction in
                    previewTransactionRow(transaction)
                }
            }
            .padding(12)
            .background(LFTheme.surface.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func previewTransactionRow(_ transaction: Transaction) -> some View {
        HStack(spacing: 14) {
            Text(formatDate(transaction.date))
                .frame(width: 84, alignment: .leading)
            Text(transaction.description)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(transaction.currency)
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 92, alignment: .leading)
            Text(transaction.credit != nil ? "Credit" : "Debit")
                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                .frame(width: 68, alignment: .leading)
            Text(formatSignedCurrency(transaction.amount, isCredit: transaction.credit != nil))
                .foregroundStyle(transaction.credit != nil ? LFTheme.success : LFTheme.danger)
                .monospacedDigit()
                .frame(width: 112, alignment: .trailing)
            Text(balanceText(transaction.balance, currency: transaction.currency))
                .foregroundStyle(LFTheme.textSecondary)
                .monospacedDigit()
                .frame(width: 86, alignment: .trailing)
        }
        .font(.caption)
        .padding(.vertical, 8)
    }

    private var importFooterAction: some View {
        Group {
            switch importState {
            case .previewReady(let preparedImport):
                Button {
                    Task {
                        await confirmPreparedImport(preparedImport)
                    }
                } label: {
                    Label("Confirm Import", systemImage: "checkmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .disabled(importIdentityReview.isAvailable && importAccountChoice == nil)
            case .committing:
                Label("Importing", systemImage: "hourglass")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LFTheme.textSecondary)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(LFTheme.surface.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .failed(_, _, let retrySourceURL) where retrySourceURL != nil:
                Button {
                    if let retrySourceURL {
                        beginPreparation(from: retrySourceURL)
                    }
                } label: {
                    Label("Retry Preparation", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            case .completed(let outcome) where outcome.allowsViewingTransactions:
                Button {
                    selectedSection = .transactions
                } label: {
                    Label("View Transactions", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 13)
                        .frame(minWidth: 180)
                        .background(LFTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            default:
                importFooterPendingAction
            }
        }
    }

    private var validationReviewPanel: some View {
        Group {
            switch importState {
            case .previewReady(let preparedImport), .validationFailed(let preparedImport), .committing(let preparedImport):
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        LFStatusBadge(
                            title: preparedImport.validation.passed ? "Validation Passed" : "Validation Failed",
                            color: preparedImport.validation.passed ? LFTheme.success : LFTheme.danger
                        )
                        LFStatusBadge(
                            title: "\(preparedImport.validation.issues.count) issue(s)",
                            color: preparedImport.validation.issues.isEmpty ? LFTheme.success : LFTheme.warning
                        )
                    }

                    LFInfoRow(title: "Rows Read", value: "\(preparedImport.validation.rowsRead)")
                    LFInfoRow(title: "Transactions Parsed", value: "\(preparedImport.validation.transactionsParsed)")
                    LFInfoRow(title: "Debit Total", value: balanceText(preparedImport.validation.debitTotal, currency: preparedImport.detectedCurrency))
                    LFInfoRow(title: "Credit Total", value: balanceText(preparedImport.validation.creditTotal, currency: preparedImport.detectedCurrency))

                    Text("No data has been written.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LFTheme.info)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LFTheme.info.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if preparedImport.validation.issues.isEmpty {
                        LFCompactEmptyState(message: "No validation issues")
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Validation Issues")
                                .font(.subheadline.weight(.semibold))
                            ForEach(preparedImport.validation.issues) { issue in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: validationIssueIcon(issue.severity))
                                        .foregroundStyle(validationIssueColor(issue.severity))
                                        .frame(width: 18)
                                    Text(issue.message)
                                        .font(.caption)
                                        .foregroundStyle(LFTheme.textSecondary)
                                }
                            }
                        }
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 12) {
                    settingsPendingRow("File Password", value: "Resolved by password provider", icon: "lock")
                    settingsPendingRow("Date Format", value: "DD MMM YYYY", icon: "calendar")
                    settingsPendingRow("Duplicate Handling", value: "Existing repository path", icon: "rectangle.on.rectangle")
                    settingsPendingRow("Create / Link Accounts", value: "Existing persistence mapper", icon: "link")
                }
            }
        }
    }

    private var importFooterPendingAction: some View {
        Label("Awaiting confirmation", systemImage: "arrow.right")
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(LFTheme.textSecondary)
            .padding(.horizontal, 32)
            .padding(.vertical, 13)
            .background(LFTheme.surface.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(LFTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func settingsPendingRow(_ title: String, value: String, icon: String) -> some View {
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
            Text("Pending")
                .font(.caption2.weight(.medium))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(LFTheme.surfaceRaised.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
            LFStatusBadge(title: status, color: status == "Success" || status == "Loaded" ? LFTheme.success : LFTheme.textSecondary)
        }
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

    private func beginPreparation(from url: URL) {
        importAccountChoice = nil
        importIdentityReview = .unavailable
        selectedFile = url.lastPathComponent
        importState = .preparing(fileName: url.lastPathComponent, phase: .openingSource)
        selectedSection = .imports
        _ = preparationOwner.start { operationID in
            await prepareImport(from: url, operationID: operationID)
        }
    }

    @MainActor
    private func prepareImport(from url: URL, operationID: UUID) async {
        do {
            let preparedImport = try await ImportEngine.shared.prepareImport(
                from: url,
                requestId: operationID
            ) { progress in
                guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                    return
                }
                importState = .preparing(fileName: url.lastPathComponent, phase: progress.phase)
            }
            guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                return
            }
            importAccountChoice = nil
            importIdentityReview = preparedImport.validation.passed && preparedImport.advisoryPreviousImport == nil
                ? (try ImportEngine.shared.reviewPreparedImport(preparedImport))
                : .unavailable
            guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                return
            }
            selectedFile = preparedImport.fileName
            importState = preparedImport.validation.passed ? .previewReady(preparedImport) : .validationFailed(preparedImport)
            releasePreparationOperation(operationID)
        } catch is CancellationError {
            guard preparationOwner.isCurrent(operationID) else {
                return
            }
            selectedFile = url.lastPathComponent
            importState = .cancelled(fileName: url.lastPathComponent)
            releasePreparationOperation(operationID)
        } catch let error as ImportError where error == .cancelled {
            guard preparationOwner.isCurrent(operationID) else {
                return
            }
            selectedFile = url.lastPathComponent
            importState = .cancelled(fileName: url.lastPathComponent)
            releasePreparationOperation(operationID)
        } catch {
            guard preparationOwner.isCurrent(operationID), !Task.isCancelled else {
                return
            }
            selectedFile = url.lastPathComponent
            importState = .failed(
                fileName: url.lastPathComponent,
                message: error.localizedDescription,
                retrySourceURL: isRetryablePreparationFailure(error) ? url : nil
            )
            DeveloperConsole.shared.log("ERROR: \(error.localizedDescription)")
            releasePreparationOperation(operationID)
        }
    }

    @MainActor
    private func confirmPreparedImport(_ preparedImport: PreparedImport) async {
        guard case .previewReady(let currentPreparedImport) = importState,
              currentPreparedImport.id == preparedImport.id else {
            return
        }

        importState = .committing(preparedImport)
        let result = await ImportEngine.shared.commitPreparedImport(
            preparedImport,
            accountChoice: importAccountChoice
        )

        if result.requiresHydration {
            do {
                let hydrationResult = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
                dashboardViewModel.markHydrationCompleted(hydrationResult)
            } catch {
                dashboardViewModel.markHydrationFailed(error)
                DeveloperConsole.shared.log("Dashboard Hydration Refresh: FAILED")
                DeveloperConsole.shared.log(error.localizedDescription)
            }
        } else if result.requiresImportAttemptRefresh {
            do {
                try RepositoryStoreHydrator().hydrateImportAttempts()
            } catch {
                DeveloperConsole.shared.log("Import attempt history refresh failed.")
            }
        }
        let outcome = ImportOutcomePresentation(result: result)
        selectedFile = result.fileName
        importState = .completed(outcome)
    }

    private func cancelPreparedImport() {
        let fileName: String
        switch importState {
        case .preparing(let currentFileName, _):
            fileName = currentFileName
            preparationOwner.cancel()
        case .previewReady(let preparedImport), .validationFailed(let preparedImport):
            fileName = preparedImport.fileName
        default:
            return
        }
        importAccountChoice = nil
        importIdentityReview = .unavailable
        selectedFile = fileName
        importState = .cancelled(fileName: fileName)
    }

    @MainActor
    private func releasePreparationOperation(_ operationID: UUID) {
        preparationOwner.finish(operationID)
    }

    private func isRetryablePreparationFailure(_ error: Error) -> Bool {
        guard let importError = error as? ImportError else {
            return false
        }
        switch importError {
        case .readerFailure, .unknown:
            return true
        case .unsupportedFile, .passwordRequired, .incorrectPassword, .readerUnavailable,
                .invalidDocument, .unsupportedStatement, .cancelled:
            return false
        }
    }

    private func statementPeriodText(_ period: ClosedRange<Date>?) -> String {
        guard let period else { return "Unknown" }
        if period.lowerBound == period.upperBound {
            return formatDate(period.lowerBound)
        }
        return "\(formatDate(period.lowerBound)) - \(formatDate(period.upperBound))"
    }

    private func balanceText(_ value: Decimal?, currency: String?) -> String {
        guard let value else { return "Unknown" }
        return formatCurrency(value, currencyCode: currency ?? "INR")
    }

    private func validationIssueIcon(_ severity: ValidationSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private func validationIssueColor(_ severity: ValidationSeverity) -> Color {
        switch severity {
        case .info:
            return LFTheme.info
        case .warning:
            return LFTheme.warning
        case .error:
            return LFTheme.danger
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return Self.dateFormatter.string(from: date)
    }

    private func formatCurrency(_ value: Decimal, currencyCode: String = "INR") -> String {
        guard let money = try? Money(amount: value, currency: currencyCode) else {
            return "\(currencyCode) \(value)"
        }
        return MoneyFormatting.display(money)
    }

    private func formatSignedCurrency(_ value: Decimal, isCredit: Bool) -> String {
        let prefix = isCredit ? "+" : "-"
        let magnitude = value < .zero ? -value : value
        return "\(prefix)\(formatCurrency(magnitude, currencyCode: "INR"))"
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
