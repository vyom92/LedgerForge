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

                toolbarBadge("Environment: Local", color: LFTheme.success)
                toolbarBadge(Self.timeFormatter.string(from: Date()), color: LFTheme.textSecondary)

                Button {
                    // Console mutation is out of Sprint 22 scope; this is a visual shell control.
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(LFTheme.primaryGradient)
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
            filterMenu("Log Level", value: "All")
            filterMenu("Source", value: "All")
            LFSearchField(placeholder: "Search logs...")
            Button {
                // Visual-only pause control for the shell.
            } label: {
                Label("Pause", systemImage: "pause")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LFTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            toolbarBadge("Live", color: LFTheme.success)
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
                            Text(Self.timeFormatter.string(from: Date()))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 86, alignment: .leading)

                            statusBadge(level(for: message), color: color(for: message))
                                .frame(width: 72, alignment: .leading)

                            Text(source(for: message))
                                .font(.caption)
                                .foregroundStyle(LFTheme.textSecondary)
                                .frame(width: 132, alignment: .leading)

                            Text(message)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(index.isMultiple(of: 2) ? "45ms" : "120ms")
                                .font(.caption2)
                                .foregroundStyle(LFTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(LFTheme.surfaceRaised)
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
            Button {
                // Command execution is out of Sprint 22 scope.
            } label: {
                Label("Execute", systemImage: "play")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(LFTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
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
            infoRow("Engine", value: "SQLite")
            infoRow("Path", value: "~/Application Support/LedgerForge")
            infoRow("Boundary", value: "Repository protocols")
            Button {
                // Opening external database tools is out of Sprint 22 scope.
            } label: {
                Label("Open in DB Browser", systemImage: "cylinder")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LFTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
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
            featureFlag("AI Category Detection", enabled: false)
            featureFlag("Advanced Parsing Engine", enabled: true)
        }
    }

    private func tab(_ title: String, selected: Bool = false) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(selected ? LFTheme.primaryHover : LFTheme.textSecondary)
            .padding(.vertical, 10)
    }

    private func filterMenu(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(LFTheme.textSecondary)
            Text(value)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 180)
        .background(LFTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func toolbarBadge(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(LFTheme.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 7))
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

    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(LFTheme.textSecondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
        .padding(.vertical, 5)
    }

    private func toolRow(_ title: String, color: Color = LFTheme.text) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(color)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(color)
        }
        .font(.caption)
        .padding(.vertical, 8)
    }

    private func featureFlag(_ title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(enabled ? "ON" : "OFF")
                .font(.caption2.weight(.bold))
                .foregroundStyle(enabled ? LFTheme.success : LFTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((enabled ? LFTheme.success : LFTheme.textSecondary).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .font(.caption)
        .padding(.vertical, 6)
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
