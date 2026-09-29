import SwiftUI
import UniformTypeIdentifiers

struct EmailStatementsSettingsView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: GmailIntakeSession

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
            LFPanel(title: "Email Statements", systemImage: "envelope") {
                if let account = session.account {
                    Text(account).font(theme.typography.rowTitle).textSelection(.enabled)
                }
                Label(session.connectionSummary, systemImage: session.isConnected ? "checkmark.circle" : "envelope.badge")
                    .font(theme.typography.secondary)
                Text("Manually fetch original attachments from the senders you select. Review and import them in Import Centre.")
                    .font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LFPanel(title: "Senders", systemImage: "person.crop.circle.badge.checkmark") {
                Text("\(session.selectedSenders.count) of \(session.senderRules.count) selected for the next collection")
                    .font(theme.typography.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.small) {
                        ForEach(session.senderRules) { rule in
                            HStack(spacing: theme.spacing.controlGap) {
                                Toggle("Include \(rule.address)", isOn: Binding(
                                    get: { rule.isSelected },
                                    set: { session.selectSender(rule.address, selected: $0) }))
                                    .toggleStyle(.checkbox).labelsHidden()
                                Button { session.selectedSenderAddress = rule.address } label: {
                                    Text(rule.address).font(theme.typography.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Select sender \(rule.address) for editing")
                            }
                            .padding(theme.spacing.small)
                            .background(session.selectedSenderAddress == rule.address ? theme.palette.accent.opacity(0.14) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radius.control))
                        }
                    }
                }
                .frame(height: 210)
                .disabled(!session.canEditSenders)
                Text("Known addresses are prefilled. Use Add, Edit or Remove below to maintain the list. Removing a sender keeps saved originals. IBKR and Zurich ISP use their existing separate paths.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LFPanel(title: "Email delivery dates", systemImage: "calendar") {
                Toggle("All available history", isOn: $session.allHistory)
                    .toggleStyle(.checkbox)
                    .font(theme.typography.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.sectionGap) { dateControls }
                    VStack(alignment: .leading, spacing: theme.spacing.controlGap) { dateControls }
                }
                .disabled(session.allHistory)
                Picker("Timezone", selection: $session.timeZoneIdentifier) {
                    Text("UTC").tag("UTC")
                    Text("Qatar · UTC+03:00").tag("Asia/Qatar")
                }
                .frame(maxWidth: 340, alignment: .leading)
                .font(theme.typography.secondary)
                Text("From and To include the selected calendar days. Collection uses the email's received time and stops at a fixed time when it starts.")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let covered = session.completedThroughForSelection {
                    Text("Last complete interval for these senders ended \(AppDateDisplay.timestamp(covered, zone: TimeZone(secondsFromGMT: 0)!))")
                        .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                }
                if let scan = session.inbox?.activeScan {
                    Text("An incomplete collection for \(scan.interval.senders.count) senders is saved through \(AppDateDisplay.timestamp(scan.interval.until, zone: TimeZone(secondsFromGMT: 0)!)). Resume uses that saved sender selection.")
                        .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(session.isCollecting)
            if session.isCollecting || session.progress.isComplete {
                LFPanel(title: session.isCollecting ? "Collecting originals" : "Collection saved", systemImage: "tray.and.arrow.down") {
                    if session.isCollecting { ProgressView().controlSize(.small) }
                    Text("\(session.progress.accountedMessages) messages accounted for · \(session.progress.downloadedOriginals) originals saved · \(session.progress.reusedOriginals) reused")
                        .font(theme.typography.secondary).monospacedDigit()
                    if session.progress.unavailableOriginals > 0 {
                        Text("\(session.progress.unavailableOriginals) originals unavailable or held at collection.")
                            .font(theme.typography.secondary).foregroundStyle(LFTheme.warning)
                    }
                }
            }
            if let message = session.message {
                Text(message).font(theme.typography.secondary).foregroundStyle(theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("emailStatements.status")
            }
            Text("Originals and intake receipts are retained with your ledger and included in LedgerForge backups. Gmail messages and labels are unchanged.")
                .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(theme.palette.primaryText)
        .environment(\.timeZone, TimeZone(identifier: session.timeZoneIdentifier) ?? .gmt)
    }

    @ViewBuilder private var dateControls: some View {
        DatePicker("From", selection: $session.fromDate, displayedComponents: .date)
            .datePickerStyle(.field).font(theme.typography.secondary)
        DatePicker("To", selection: $session.throughDate, displayedComponents: .date)
            .datePickerStyle(.field).font(theme.typography.secondary)
    }
}

struct EmailStatementsFooter: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: GmailIntakeSession
    let openImportCentre: () -> Void
    @State private var selectingClient = false
    @State private var configurationMessage: String?
    @State private var editingSender = false
    @State private var originalSender: String?
    @State private var senderAddress = ""
    @State private var senderError: String?
    @State private var replacingScan = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.small) {
            HStack(spacing: theme.spacing.controlGap) {
                Button("Add sender…") {
                    originalSender = nil; senderAddress = ""; senderError = nil; editingSender = true
                }.lfSecondaryAction().disabled(!session.canEditSenders)
                Button("Edit sender…") {
                    originalSender = session.selectedSenderAddress
                    senderAddress = originalSender ?? ""; senderError = nil; editingSender = true
                }.lfSecondaryAction().disabled(!session.canEditSenders || session.selectedSenderAddress == nil)
                Button("Remove sender", action: session.removeSelectedSender)
                    .lfSecondaryAction().disabled(!session.canEditSenders || session.selectedSenderAddress == nil)
                Spacer()
            }
            if let configurationMessage {
                Text(configurationMessage).font(theme.typography.caption).foregroundStyle(LFTheme.warning)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: theme.spacing.controlGap) { controls }
                VStack(alignment: .trailing, spacing: theme.spacing.controlGap) { controls }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(theme.spacing.pagePadding)
        .sheet(isPresented: $editingSender) { [originalSender] in
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                Text(originalSender == nil ? "Add sender" : "Edit sender").font(theme.typography.rowTitle)
                TextField("Email address", text: $senderAddress).textFieldStyle(.roundedBorder)
                    .onSubmit(saveSender)
                if let senderError { Text(senderError).font(theme.typography.secondary).foregroundStyle(LFTheme.warning) }
                HStack {
                    Spacer()
                    Button("Cancel") { editingSender = false }.keyboardShortcut(.cancelAction)
                    Button("Save", action: saveSender).keyboardShortcut(.defaultAction)
                }
            }
            .padding(theme.spacing.pagePadding).frame(width: 440)
        }
        .confirmationDialog("Start a new collection?", isPresented: $replacingScan) {
            Button("Fetch selected senders") { session.collectSelectedRange(replaceIncomplete: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved originals and receipts will remain. This replaces the unfinished scan with your selected senders and dates; the old scan will not count as complete.")
        }
        .fileImporter(isPresented: $selectingClient, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size > 0, size <= 32_768 else { throw GmailIntakeError.configurationRequired }
                let data = try Data(contentsOf: url)
                _ = try GmailDesktopClient.read(data)
                configurationMessage = nil
                session.connect(configuration: data)
            } catch {
                configurationMessage = "Choose the existing Desktop OAuth client JSON used for this Gmail connection."
            }
        }
    }

    private func saveSender() {
        do {
            try session.saveSender(senderAddress, replacing: originalSender)
            editingSender = false
        } catch { senderError = error.localizedDescription }
    }

    @ViewBuilder private var controls: some View {
        Button("Open Import Centre", action: openImportCentre).lfSecondaryAction()
        if session.isCollecting {
            Button("Stop collection", action: session.cancelCollection).lfSecondaryAction()
        } else {
            if session.needsClientConfiguration {
                Button("Select existing OAuth client…") { selectingClient = true }.lfSecondaryAction()
            } else if session.needsAuthorization {
                Button("Reconnect in browser…") { session.connect(reauthorize: true) }
                    .lfSecondaryAction().disabled(session.isChecking)
            } else {
                Button(session.isConnected ? "Check connection" : "Use saved connection") { session.connect() }
                    .lfSecondaryAction().disabled(session.isChecking)
            }
            if session.inbox?.activeScan != nil {
                Button("Resume collection", action: session.resumeCollection)
                    .lfSecondaryAction().disabled(!session.canCollect)
            } else {
                if session.completedThroughForSelection != nil {
                    Button("Collect since last complete", action: session.collectIncremental)
                        .lfSecondaryAction().disabled(!session.canStartCollection)
                }
            }
            Button("Fetch selected senders") {
                if session.inbox?.activeScan != nil { replacingScan = true }
                else { session.collectSelectedRange() }
            }
            .buttonStyle(LFActionButtonStyle(kind: .primary)).disabled(!session.canStartCollection)
            .accessibilityIdentifier("emailStatements.collect")
        }
    }
}

struct EmailInboxQueueView: View {
    @Environment(\.lfTheme) private var theme
    @ObservedObject var session: GmailIntakeSession

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.controlGap) {
            HStack {
                Label("Email originals", systemImage: "tray.full").font(theme.typography.rowTitle)
                Spacer()
                Text("\(session.sources.count) retained · \(session.batchSources.count) queued")
                    .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
            }
            List(selection: $session.selectedSourceID) {
                ForEach(session.sources) { source in
                    VStack(alignment: .leading, spacing: theme.spacing.micro) {
                        Text(source.displayName).font(theme.typography.secondary).lineLimit(2)
                        Text("\(source.family.displayName) · \(session.status(for: source))")
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                        Text("Received \(AppDateDisplay.timestamp(Date(timeIntervalSince1970: Double(source.receivedMilliseconds) / 1_000)))")
                            .font(theme.typography.caption).foregroundStyle(theme.palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, theme.spacing.small)
                    .contentShape(Rectangle())
                    .tag(source.id)
                    .accessibilityLabel("\(source.displayName), \(session.status(for: source))")
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(height: 280)
            .accessibilityIdentifier("emailOriginals.list")
        }
    }
}
