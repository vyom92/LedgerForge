// LedgerForge
// DeveloperConsoleView.swift
// Version: 0.0.4

import SwiftUI

struct DeveloperConsoleView: View {

    @ObservedObject var console = DeveloperConsole.shared

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                LFSearchField(placeholder: "Search console...")
                    .frame(maxWidth: 420)

                Spacer()

                LFInlineBadge(title: "Environment: Local", color: LFTheme.success)
                LFInlineBadge(title: Self.timeFormatter.string(from: Date()), color: LFTheme.textSecondary)

                Label("Refresh pending", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LFTheme.textSecondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(LFTheme.surfaceRaised.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(LFTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }

            HStack(alignment: .top, spacing: 14) {
                LFPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        consoleTabs
                        consoleFilters
                        consoleLogTable
                        commandBar
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    systemOverviewPanel
                    databasePanel
                    toolsPanel
                    featureFlagsPanel
                }
                .frame(width: 330)
            }
        }
        .padding(28)
        .background(LFTheme.backgroundGradient)
    }

    private var consoleTabs: some View {
        HStack(spacing: 24) {
            tab("Console", selected: true)
            tab("Database")
            tab("SQL Editor")
            tab("Background Jobs")
            tab("File Inspector")
            tab("Logs")
            tab("Feature Flags")
            Spacer()
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(LFTheme.primary)
                .frame(width: 76, height: 2)
        }
    }

    private var consoleFilters: some View {
        HStack(spacing: 12) {
            LFFilterChip(title: "Log Level", value: "Pending", width: 180, surface: LFTheme.surfaceRaised.opacity(0.65), showsChevron: false)
            LFFilterChip(title: "Source", value: "Pending", width: 180, surface: LFTheme.surfaceRaised.opacity(0.65), showsChevron: false)
            LFSearchField(placeholder: "Search logs...")
            Label("Pause pending", systemImage: "pause")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LFTheme.surfaceRaised.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LFTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
            LFInlineBadge(title: "Live", color: LFTheme.success)
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
                } else {
                    ForEach(Array(console.messages.enumerated()), id: \.offset) { index, message in
                        HStack(spacing: 14) {
                            Text("#\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 86, alignment: .leading)

                            LFStatusBadge(title: level(for: message), color: color(for: message))
                                .frame(width: 72, alignment: .leading)

                            Text(source(for: message))
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 132, alignment: .leading)

                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("local")
                                .font(.caption2)
                                .foregroundStyle(LFTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(LFTheme.surfaceRaised.opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(.vertical, 10)

                        Divider().overlay(LFTheme.divider)
                    }
                }
            }
        }
        .frame(minHeight: 430)
    }

    private var commandBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(LFTheme.textSecondary)
            Text("Enter console command...")
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
            Spacer()
            Label("Commands pending", systemImage: "play")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(LFTheme.surfaceRaised.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LFTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding(12)
        .background(LFTheme.backgroundDeep.opacity(0.65))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LFTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var systemOverviewPanel: some View {
        LFPanel(title: "System Overview") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                overviewMetric("CPU Usage", value: "Local")
                overviewMetric("Memory Usage", value: "Runtime")
                overviewMetric("Disk Usage", value: "Offline")
                overviewMetric("Background Jobs", value: "0 Running", color: LFTheme.success)
            }
        }
    }

    private var databasePanel: some View {
        LFPanel(title: "Database") {
            LFInfoRow(title: "Engine", value: "SQLite", verticalPadding: 5)
            LFInfoRow(title: "Path", value: "~/Application Support/LedgerForge", verticalPadding: 5)
            LFInfoRow(title: "Boundary", value: "Repository protocols", verticalPadding: 5)
            Label("DB Browser pending", systemImage: "cylinder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(LFTheme.surfaceRaised.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(LFTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private var toolsPanel: some View {
        LFPanel(title: "Tools") {
            toolRow("Reindex Search Index")
            toolRow("Recalculate Account Balances")
            toolRow("Clear Application Cache")
            toolRow("Reset Onboarding")
            toolRow("Reset Database (Danger Zone)", color: LFTheme.danger)
        }
    }

    private var featureFlagsPanel: some View {
        LFPanel(title: "Feature Flags") {
            featureFlag("AI Category Detection", status: "Future")
            featureFlag("Advanced Parsing Engine", status: "Current")
        }
    }

    private func tab(_ title: String, selected: Bool = false) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(selected ? LFTheme.primaryHover : LFTheme.textSecondary)
            .padding(.vertical, 10)
    }

    private func overviewMetric(_ title: String, value: String, color: Color = LFTheme.text) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(LFTheme.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LFTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toolRow(_ title: String, color: Color = LFTheme.text) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(color)
            Spacer()
            Text("Pending")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LFTheme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(LFTheme.surfaceRaised.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .font(.caption)
        .padding(.vertical, 8)
    }

    private func featureFlag(_ title: String, status: String) -> some View {
        let isCurrent = status == "Current"
        return HStack {
            Text(title)
            Spacer()
            Text(status)
                .font(.caption2.weight(.bold))
                .foregroundStyle(isCurrent ? LFTheme.success : LFTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((isCurrent ? LFTheme.success : LFTheme.textSecondary).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .font(.caption)
        .padding(.vertical, 6)
    }

    private func level(for message: String) -> String {
        if message.localizedCaseInsensitiveContains("failed") || message.localizedCaseInsensitiveContains("error") {
            return "ERROR"
        }
        if message.localizedCaseInsensitiveContains("warning") || message.localizedCaseInsensitiveContains("review") {
            return "WARN"
        }
        if message.localizedCaseInsensitiveContains("completed") || message.localizedCaseInsensitiveContains("success") {
            return "SUCCESS"
        }
        return "INFO"
    }

    private func color(for message: String) -> Color {
        switch level(for: message) {
        case "ERROR":
            return LFTheme.danger
        case "WARN":
            return LFTheme.warning
        case "SUCCESS":
            return LFTheme.success
        default:
            return LFTheme.info
        }
    }

    private func source(for message: String) -> String {
        if let separator = message.firstIndex(of: ":") {
            return String(message[..<separator])
        }
        return "LedgerForge"
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
