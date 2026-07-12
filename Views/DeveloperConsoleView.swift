// LedgerForge
// DeveloperConsoleView.swift
// Version: 0.0.4

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

struct DeveloperConsoleView: View {

    @ObservedObject var console = DeveloperConsole.shared
    @ObservedObject private var accountStore = AccountStore.shared
    @ObservedObject private var transactionStore = TransactionStore.shared

    // Filters
    @State private var filters = DeveloperConsole.Filters()
    @State private var selectedLevel: LevelPicker = .all
    @State private var selectedCategory: CategoryPicker = .all

    // UI State
    @State private var hydrationStatus = "Not refreshed in console"
    @State private var latestRefreshResult = "No console refresh yet"
    @State private var actionError: String?
    @State private var isRunningRepositoryAction = false
    @State private var showsResetConfirmation = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                LFInlineBadge(title: "Environment: Local", color: LFTheme.success)
                LFInlineBadge(title: LedgerForgeApp.currentProviderState(), color: LFTheme.info)

                Spacer()

                LFInlineBadge(title: Self.timeFormatter.string(from: Date()), color: LFTheme.textSecondary)
            }

            HStack(alignment: .top, spacing: 14) {
                LFPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        logHeader
                        consoleLogTable
                        logActions
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    runtimeInspectorPanel
                    repositorySummaryPanel
                    toolsPanel
                }
                .frame(width: 330)
            }
        }
        .padding(28)
        .background(LFTheme.backgroundGradient)
        .confirmationDialog(
            "Reset Development Database?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Development Database", role: .destructive) {
                resetDevelopmentDatabase()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This irreversible development action removes all imported financial data and import history by switching to a fresh SQLite database. Application preferences, appearance and Developer Mode are preserved.")
        }
        .onChange(of: selectedLevel) { _, _ in
            applyLevelFilter()
        }
        .onChange(of: selectedCategory) { _, _ in
            applyCategoryFilter()
        }
    }

    private var runtimeSnapshot: DeveloperConsoleSnapshot {
        DeveloperConsole.runtimeSnapshot(
            providerState: LedgerForgeApp.currentProviderState(),
            databasePath: LedgerForgeApp.currentSQLiteDatabasePath(),
            hydrationStatus: hydrationStatus,
            latestRefreshResult: latestRefreshResult,
            accountStore: accountStore,
            transactionStore: transactionStore
        )
    }

    private var displayedEntries: [DeveloperLogEntry] {
        let filtered = console.filteredEntries(using: filters)
        return DeveloperConsole.newestFirst(filtered)
    }

    private var logHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text("Developer Diagnostics")
                    .font(.headline)
                Spacer()
                LFInlineBadge(title: "\(displayedEntries.count) shown", color: LFTheme.textSecondary)
            }

            HStack(spacing: 10) {
                // Level filter
                Picker("Level", selection: $selectedLevel) {
                    Text("All Levels").tag(LevelPicker.all)
                    Text("Debug").tag(LevelPicker.debug)
                    Text("Info").tag(LevelPicker.info)
                    Text("Warning").tag(LevelPicker.warning)
                    Text("Error").tag(LevelPicker.error)
                }
                .pickerStyle(.menu)
                .frame(width: 160)

                // Category filter
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag(CategoryPicker.all)
                    Text("Application").tag(CategoryPicker.application)
                    Text("Import").tag(CategoryPicker.`import`)
                    Text("Parser").tag(CategoryPicker.parser)
                    Text("Validation").tag(CategoryPicker.validation)
                    Text("Database").tag(CategoryPicker.database)
                    Text("Runtime").tag(CategoryPicker.runtime)
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                // Search
                TextField("Search diagnostics (message, metadata)", text: $filters.searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(LFTheme.surfaceRaised.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(LFTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    private var consoleLogTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if console.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.system(size: 34))
                            .foregroundStyle(LFTheme.primaryHover)
                        Text("No console messages")
                            .font(.headline)
                        Text("Runtime diagnostics appear here when import, validation or hydration emits messages.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else if displayedEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundStyle(LFTheme.primaryHover)
                        Text("No matching console messages")
                            .font(.headline)
                        Text("Search filters the visible messages only.")
                            .font(.caption)
                            .foregroundStyle(LFTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(displayedEntries) { entry in
                        logRow(entry)
                        Divider().overlay(LFTheme.divider)
                    }
                }
            }
        }
        .frame(minHeight: 430)
    }

    @ViewBuilder
    private func logRow(_ entry: DeveloperLogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("#\(entry.sequence)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(LFTheme.textSecondary)
                .frame(width: 86, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(Self.rowTimeFormatter.string(from: entry.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(LFTheme.textSecondary)

                    levelBadge(entry.level)
                    categoryBadge(entry.category)
                }

                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let metadataText = DeveloperConsole.metadataText(for: entry) {
                    Text(metadataText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(LFTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private func levelBadge(_ level: DeveloperLogLevel) -> some View {
        let color: Color = {
            switch level {
            case .debug: return LFTheme.textSecondary
            case .info: return LFTheme.info
            case .warning: return LFTheme.warning
            case .error: return LFTheme.danger
            }
        }()
        return Text(level.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func categoryBadge(_ category: DeveloperLogCategory) -> some View {
        Text(category.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(LFTheme.surfaceRaised.opacity(0.65))
            .foregroundStyle(LFTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var logActions: some View {
        HStack(spacing: 10) {
            Spacer()

            LFConsoleButton(
                title: "Copy All",
                systemImage: "doc.on.doc",
                minWidth: 104,
                fill: LFTheme.surfaceRaised.opacity(0.65)
            ) {
                copyAllLogs()
            }

            LFConsoleButton(
                title: "Clear",
                systemImage: "trash",
                minWidth: 88,
                fill: LFTheme.surfaceRaised.opacity(0.65),
                foreground: LFTheme.danger
            ) {
                console.clear()
                // Reset presentation state
                filters = DeveloperConsole.Filters()
                selectedLevel = .all
                selectedCategory = .all
            }
        }
        .padding(12)
        .background(LFTheme.backgroundDeep.opacity(0.65))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LFTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var runtimeInspectorPanel: some View {
        LFPanel(title: "Runtime Inspector") {
            VStack(spacing: 0) {
                LFInfoRow(title: "Provider", value: runtimeSnapshot.providerState, verticalPadding: 5)
                LFInfoRow(title: "Hydration", value: runtimeSnapshot.hydrationStatus, verticalPadding: 5)
                LFInfoRow(title: "Latest Refresh", value: runtimeSnapshot.latestRefreshResult, verticalPadding: 5)
                LFInfoRow(title: "Accounts", value: "\(runtimeSnapshot.accountCount)", verticalPadding: 5)
                LFInfoRow(title: "Transactions", value: "\(runtimeSnapshot.transactionCount)", verticalPadding: 5)
                if let databasePath = runtimeSnapshot.databasePath {
                    LFInfoRow(title: "SQLite Path", value: databasePath, verticalPadding: 5)
                }
            }
        }
    }

    private var repositorySummaryPanel: some View {
        LFPanel(title: "Repository Summary") {
            VStack(spacing: 0) {
                LFInfoRow(title: "Accounts", value: "\(runtimeSnapshot.accountCount)", verticalPadding: 5)
                LFInfoRow(title: "Transactions", value: "\(runtimeSnapshot.transactionCount)", verticalPadding: 5)
            }
        }
    }

    private var toolsPanel: some View {
        LFPanel(title: "Tools") {
            VStack(spacing: 10) {
                LFConsoleButton(
                    title: "Reload Data",
                    systemImage: "arrow.clockwise",
                    fill: LFTheme.surfaceRaised.opacity(0.65),
                    isFullWidth: true,
                    isDisabled: isRunningRepositoryAction
                ) {
                    reloadData()
                }

                LFConsoleButton(
                    title: "Reset Development Database",
                    systemImage: "exclamationmark.triangle",
                    fill: LFTheme.danger,
                    foreground: .white,
                    isFullWidth: true,
                    showsBorder: false,
                    isDisabled: isRunningRepositoryAction
                ) {
                    showsResetConfirmation = true
                }

                if let actionError {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(LFTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func applyLevelFilter() {
        switch selectedLevel {
        case .all:
            filters.level = .all
        case .debug:
            filters.level = .exact(.debug)
        case .info:
            filters.level = .exact(.info)
        case .warning:
            filters.level = .exact(.warning)
        case .error:
            filters.level = .exact(.error)
        }
    }

    private func applyCategoryFilter() {
        switch selectedCategory {
        case .all:
            filters.category = .all
        case .application:
            filters.category = .exact(.application)
        case .`import`:
            filters.category = .exact(.`import`)
        case .parser:
            filters.category = .exact(.parser)
        case .validation:
            filters.category = .exact(.validation)
        case .database:
            filters.category = .exact(.database)
        case .runtime:
            filters.category = .exact(.runtime)
        }
    }

    private func reloadData() {
        isRunningRepositoryAction = true
        actionError = nil
        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
            hydrationStatus = result.didHydrate ? "Forced refresh completed" : "No refresh required"
            latestRefreshResult = "\(result.accountCount) account(s), \(result.transactionCount) transaction(s)"
            DeveloperConsole.shared.info(.runtime, "Runtime refresh completed", metadata: ["accounts": "\(result.accountCount)", "transactions": "\(result.transactionCount)"])
        } catch {
            hydrationStatus = "Forced refresh failed"
            latestRefreshResult = "Refresh failed"
            actionError = error.localizedDescription
            DeveloperConsole.shared.error(.runtime, "Runtime refresh failed", metadata: ["error": error.localizedDescription])
        }
        isRunningRepositoryAction = false
    }

    private func resetDevelopmentDatabase() {
        isRunningRepositoryAction = true
        actionError = nil
        do {
            let result = try LedgerForgeApp.resetDevelopmentDatabase()
            hydrationStatus = "Reset hydration completed"
            latestRefreshResult = "\(result.accountCount) account(s), \(result.transactionCount) transaction(s)"
            DeveloperConsole.shared.info(.database, "Development database reset", metadata: ["accounts": "\(result.accountCount)", "transactions": "\(result.transactionCount)"])
        } catch {
            hydrationStatus = "Reset failed"
            latestRefreshResult = "Reset failed"
            actionError = error.localizedDescription
            DeveloperConsole.shared.error(.database, "Development database reset failed", metadata: ["error": error.localizedDescription])
        }
        isRunningRepositoryAction = false
    }

    private func copyAllLogs() {
        let text = console.completeLogText
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        DeveloperConsole.shared.info(.application, "Copied complete diagnostic history")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let rowTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

// MARK: - Picker Models

private enum LevelPicker: Hashable {
    case all, debug, info, warning, error
}

private enum CategoryPicker: Hashable {
    case all, application, `import`, parser, validation, database, runtime
}

struct DeveloperConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        DeveloperConsoleView()
    }
}
