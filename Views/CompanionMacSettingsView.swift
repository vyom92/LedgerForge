import SwiftUI
import AppKit

/// Settings content only. The parent owns the coordinator and foreground lifecycle.
@MainActor
struct CompanionMacSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: CompanionMacCoordinator
    var availableWidth: CGFloat = 0
    @State private var phoneCode = ""
    @State private var choosingFolder = false
    @State private var folderAction: FolderAction?
    @State private var localMessage: String?
    @State private var runningAction = false

    private enum FolderAction { case pair(String), reconnect }
    private var validPhoneCode: String? {
        UUID(uuidString: phoneCode.trimmingCharacters(in: .whitespacesAndNewlines))?.uuidString
    }
    private var busy: Bool { session.isChecking || runningAction || choosingFolder }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFSettingsPageHeader("iPhone Companion", subtitle: "Read your Mac snapshot and edit Monthly Plan entries on your iPhone.") {
                if busy { ProgressView().controlSize(.small).accessibilityLabel("Checking companion connection") }
            }
            LFSettingsColumns(availableWidth: availableWidth) {
                if let recovery = session.recoveryReview {
                    CompanionMacLedgerRecoveryView(reviewID: recovery.id, phoneID: recovery.phoneID,
                        previousLedgerLabel: "Previously paired Mac ledger", currentLedgerLabel: "Current Mac database",
                        isWorking: busy, permitsNewFolder: true, message: nil,
                        onConfirmAndChooseNewFolder: session.beginLedgerRecovery)
                } else { connectionPanel }
            } trailing: {
                statusPanel
            }
            if session.phoneID != nil { versionControls }
            if let writer = session.reviewWriter, !session.fileChoices.isEmpty {
                versionChoices(writer)
            }
            if let message = localMessage ?? session.message {
                Text(message)
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("companionSettings.message")
            }
        }
        .font(theme.typography.body)
        .foregroundStyle(theme.palette.primaryText)

    }

    private var connectionPanel: some View {
        LFPanel(title: "Connection") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                if let phoneID = session.phoneID {
                    LabeledContent("Paired iPhone") {
                        Text(phoneID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                    LabeledContent("Companion folder", value: session.folderName ?? "Folder access needs reconnecting")
                    Button("Reconnect folder", systemImage: "folder") {
                        chooseFolder(.reconnect)
                    }.lfConnectAction()
                    .disabled(busy || choosingFolder)
                    .help("Choose the same companion folder to renew access while retaining the existing pairing.")
                } else {
                    Text("On your iPhone, open Connection and copy its pairing code. Paste the code here, then choose a folder in iCloud Drive that you can select on both devices.")
                        .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("iPhone pairing code", text: $phoneCode)
                        .textFieldStyle(.roundedBorder)
                        .disabled(busy || choosingFolder)
                        .accessibilityIdentifier("companionSettings.phoneCode")
                    if !phoneCode.isEmpty, validPhoneCode == nil {
                        Text("Paste the complete pairing code shown on the iPhone.")
                            .font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                    }
                    Button("Choose folder and pair", systemImage: "folder.badge.plus") {
                        guard let phoneID = validPhoneCode else { return }
                        chooseFolder(.pair(phoneID))
                    }.lfConnectAction()
                    .disabled(validPhoneCode == nil || busy || choosingFolder)
                    Text("After pairing, choose this same folder in the iPhone app.")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
            }
        }
    }

    private var statusPanel: some View {
        LFPanel(title: "Updates and checks") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Text(session.status).font(theme.typography.rowTitle)
                    .accessibilityIdentifier("companionSettings.status")
                if let published = session.lastPublishedAt {
                    LabeledContent("Last snapshot saved to folder") { Text(published, format: .dateTime) }
                }
                if let checked = session.lastCheckedAt {
                    LabeledContent("Last folder check") { Text(checked, format: .dateTime) }
                }
                Button("Check and save snapshot", systemImage: "arrow.clockwise") { run { await session.exchange() } }
                    .disabled(busy || session.phoneID == nil || session.folderName == nil)
                Text("While LedgerForge is your active app, the Mac checks for iPhone edits and saves its latest snapshot to the shared folder. The iPhone keeps its last received snapshot and saved edits when either device is offline.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A snapshot saved to the folder may not have reached your iPhone yet. The iPhone marks an edit as acknowledged only after it receives a matching receipt from the Mac. The saved-snapshot time and last folder check refer to separate events.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var versionControls: some View {
        LFPanel(title: "iCloud version review") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Text("If iCloud reports different versions, review the Mac or iPhone file. Every available version is retained locally before a selection can be applied.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Review Mac versions") { run { await session.reviewVersions(.mac) } }
                    Button("Review iPhone versions") { run { await session.reviewVersions(.phone) } }
                }.disabled(busy || session.folderName == nil)
            }
        }
    }

    private func versionChoices(_ writer: CompanionWriter) -> some View {
        LFPanel(title: writer == .mac ? "Mac file versions" : "iPhone file versions") {
            VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
                Text("Choose the complete publication to use. A file-version choice is separate from resolving conflicting Monthly Plan entries.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(session.fileChoices) { choice in
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        Button(choiceLabel(choice, writer: writer)) { run { await session.resolveVersion(id: choice.id) } }
                            .disabled(busy || choice.envelope == nil || choice.issue != nil)
                        Text("Reference \(choice.id.prefix(12))")
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(theme.palette.secondaryText)
                            .textSelection(.enabled)
                        if let issue = choice.issue {
                            Text(issue).font(theme.typography.caption).foregroundStyle(LFTheme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
    private func choiceLabel(_ choice: CompanionFileChoice, writer: CompanionWriter) -> String {
        let role = writer == .mac ? "Mac" : "iPhone"
        guard let envelope = choice.envelope else { return "\(role) version unavailable for selection" }
        if choice.issue != nil { return "\(role) publication \(envelope.generation) — needs review" }
        return "Use \(role) publication \(envelope.generation)"
    }
    private func chooseFolder(_ action: FolderAction) {
        guard !busy else { return }
        localMessage = nil; folderAction = action; choosingFolder = true
        Task {
            defer { choosingFolder = false; folderAction = nil }
            guard let folder = await CompanionFolderPanel.select(), let selectedAction = folderAction else { return }
            switch selectedAction {
            case .pair(let phoneID): await session.pair(phoneID: phoneID, folder: folder)
            case .reconnect: await session.reconnect(folder: folder)
            }
        }
    }
    private func run(_ action: @escaping @MainActor () async -> Void) {
        guard !busy else { return }
        runningAction = true; localMessage = nil
        Task {
            await action()
            runningAction = false
        }
    }
}

/// Directory-only panel shared by companion connection and ledger recovery.
/// SwiftUI owns the action and busy state; no AppKit object survives this call.
@MainActor
enum CompanionFolderPanel {
    private static var presentingWindow: NSWindow? {
        if let window = NSApp.mainWindow, !(window is NSPanel) { return window }
        return NSApp.windows.first { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }
    }

    static func select(title: String = "Choose Companion Folder") async -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        let response = await withCheckedContinuation { continuation in
            if let window = presentingWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        return response == .OK ? panel.url : nil
    }
}
