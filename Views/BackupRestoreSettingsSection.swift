import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let ledgerForgeBackup = UTType(exportedAs: "com.vyom.LedgerForge.backup", conformingTo: .package)
}

@MainActor
private enum BackupFilePanel {
    // A just-dismissed file panel can briefly remain key. Attach subsequent
    // sheets to the document window, never to that retiring panel.
    private static var presentingWindow: NSWindow? {
        if let window = NSApp.mainWindow, !(window is NSPanel) { return window }
        return NSApp.windows.first { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }
    }

    static func select(destination: Bool) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = destination ? "Choose Backup Destination" : "Choose LedgerForge Backup"
        panel.prompt = destination ? "Choose Folder" : "Verify Backup"
        panel.canChooseFiles = !destination
        panel.canChooseDirectories = destination
        panel.canCreateDirectories = destination
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        if !destination { panel.allowedContentTypes = [.ledgerForgeBackup] }
        let response = await withCheckedContinuation { continuation in
            if let window = presentingWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        return response == .OK ? panel.url : nil
    }

    static func confirm(_ manifest: BackupManifest) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Replace Current Ledger?"
        let date = ISO8601DateFormatter().date(from: manifest.createdAt)
        let time = date?.formatted(date: .abbreviated, time: .shortened) ?? manifest.createdAt
        let version = manifest.application.version ?? "Version unavailable"
        let replacement = ApplicationAvailability.shared.permitsMutation
            ? "This replaces current ledger data with the selected backup. The previous ledger is retained until a successful relaunch."
            : "This installs the selected backup as Current Database. Existing recovery files are retained, but a usable previous ledger is not available."
        alert.informativeText = "Backup from \(time) · \(version)\nIntegrity and compatibility verified.\n\n\(replacement)"
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\r"
        let replace = alert.addButton(withTitle: "Replace Ledger and Restore")
        replace.keyEquivalent = ""
        replace.hasDestructiveAction = true
        let response = await withCheckedContinuation { continuation in
            if let window = presentingWindow {
                alert.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else { continuation.resume(returning: alert.runModal()) }
        }
        return response == .alertSecondButtonReturn
    }

    static func confirmNewLedger() async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Create a New Ledger?"
        alert.informativeText = "No current ledger was found. Create an empty ledger only if you are starting fresh. To recover saved data, cancel and choose Restore Backup."
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\r"
        alert.addButton(withTitle: "Create New Ledger").keyEquivalent = ""
        let response = await withCheckedContinuation { continuation in
            if let window = presentingWindow {
                alert.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else { continuation.resume(returning: alert.runModal()) }
        }
        return response == .alertSecondButtonReturn
    }
}

struct BackupRestoreSettingsSection: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject private var recovery = BackupRestoreCoordinator.shared
    @State private var selecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            Text("Backup & Restore").font(theme.typography.rowTitle)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) { actions }
                VStack(alignment: .leading, spacing: theme.spacing.controlGap) { actions }
            }
            if recovery.canCreateNewLedger {
                Button("Create New Ledger…") {
                    Task { if await BackupFilePanel.confirmNewLedger() { recovery.startNewLedger() } }
                }
                .lfSecondaryAction()
                .disabled(selecting || recovery.isBusy || recovery.candidateManifest != nil)
            }
            HStack(alignment: .top, spacing: theme.spacing.small) {
                if recovery.isBusy { ProgressView().controlSize(.small) }
                Text(recovery.message)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if recovery.canCancel && recovery.isBusy {
                Button("Cancel", action: recovery.cancel).lfSecondaryAction()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: recovery.candidateManifest) { _, manifest in
            guard let manifest else { return }
            Task {
                if await BackupFilePanel.confirm(manifest) { recovery.startReplacement() }
                else { await recovery.discardCandidate() }
            }
        }
    }

    @ViewBuilder private var actions: some View {
        Button("Create Backup…") { select(destination: true) }
            .lfSecondaryAction()
            .disabled(selecting || recovery.isBusy || recovery.candidateManifest != nil)
        Button("Restore Backup…") { select(destination: false) }
            .lfSecondaryAction()
            .disabled(selecting || recovery.isBusy || recovery.candidateManifest != nil)
    }
    private func select(destination: Bool) {
        selecting = true
        Task {
            defer { selecting = false }
            guard let url = await BackupFilePanel.select(destination: destination) else { return }
            if destination { recovery.startBackup(to: url) }
            else { recovery.startVerification(of: url) }
        }
    }
}
