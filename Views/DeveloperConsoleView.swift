// LedgerForge
// DeveloperConsoleView.swift
// Version: 0.0.4

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct DeveloperConsoleView: View {

    @ObservedObject var console = DeveloperConsole.shared
    @ObservedObject private var accountStore = AccountStore.shared
    @ObservedObject private var transactionStore = TransactionStore.shared
    @State private var logSearchText = ""
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

    private var displayedMessages: [String] {
        console.filteredMessages(matching: logSearchText)
    }

    private var logHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Log Console")
                    .font(.headline)
                Spacer()
                LFInlineBadge(title: "\(displayedMessages.count) shown", color: LFTheme.textSecondary)
            }

            TextField("Plain-text log search", text: $logSearchText)
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

    private var consoleLogTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if console.messages.isEmpty {
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
                } else if displayedMessages.isEmpty {
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
                    ForEach(Array(displayedMessages.enumerated()), id: \.offset) { index, message in
                        HStack(spacing: 14) {
                            Text("#\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 86, alignment: .leading)

                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 10)

                        Divider().overlay(LFTheme.divider)
                    }
                }
            }
        }
        .frame(minHeight: 430)
    }

    private var logActions: some View {
        HStack(spacing: 10) {
            Spacer()

            consoleButton(
                title: "Copy All",
                systemImage: "doc.on.doc",
                minWidth: 104,
                fill: LFTheme.surfaceRaised.opacity(0.65)
            ) {
                copyAllLogs()
            }

            consoleButton(
                title: "Clear",
                systemImage: "trash",
                minWidth: 88,
                fill: LFTheme.surfaceRaised.opacity(0.65),
                foreground: LFTheme.danger
            ) {
                console.clear()
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
                consoleButton(
                    title: "Reload Data",
                    systemImage: "arrow.clockwise",
                    fill: LFTheme.surfaceRaised.opacity(0.65),
                    isFullWidth: true,
                    isDisabled: isRunningRepositoryAction
                ) {
                    reloadData()
                }

                consoleButton(
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

    private func consoleButton(
        title: String,
        systemImage: String,
        minWidth: CGFloat? = nil,
        fill: Color,
        foreground: Color = LFTheme.text,
        isFullWidth: Bool = false,
        showsBorder: Bool = true,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(minWidth: minWidth)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(foreground)
                .background(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LFTheme.border, lineWidth: showsBorder ? 1 : 0)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func reloadData() {
        isRunningRepositoryAction = true
        actionError = nil
        do {
            let result = try RepositoryStoreHydrator().hydrateIfNeeded(forceRefresh: true)
            hydrationStatus = result.didHydrate ? "Forced refresh completed" : "No refresh required"
            latestRefreshResult = "\(result.accountCount) account(s), \(result.transactionCount) transaction(s)"
            DeveloperConsole.shared.log("Reload Data: \(latestRefreshResult)")
        } catch {
            hydrationStatus = "Forced refresh failed"
            latestRefreshResult = "Refresh failed"
            actionError = error.localizedDescription
            DeveloperConsole.shared.log("Reload Data: FAILED")
            DeveloperConsole.shared.log(error.localizedDescription)
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
        } catch {
            hydrationStatus = "Reset failed"
            latestRefreshResult = "Reset failed"
            actionError = error.localizedDescription
            DeveloperConsole.shared.log("Reset Development Database: FAILED")
            DeveloperConsole.shared.log(error.localizedDescription)
        }
        isRunningRepositoryAction = false
    }

    private func copyAllLogs() {
        let text = console.completeLogText
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        DeveloperConsole.shared.log("Log Console: Copied all logs")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

struct DeveloperConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        DeveloperConsoleView()
    }
}
